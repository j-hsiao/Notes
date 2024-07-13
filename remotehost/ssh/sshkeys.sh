#!/bin/bash
# manage ssh keys
# Creates a key repository
# keydir/
#   keyname1/
#       keyname1
#       keyname1.pub
#   keyname2/
#       keyname2
#       keyname2.pub
#   ...
#
# When keys are installed, replicate keydir structure
# without the public keys as
# ${HOME}/.ssh/keys/
#   keyname1/
#       keyname1
#   keyname2/
#       keyname2
#
# This way, ${HOME}/.ssh/keys can also be used as
# a key repository
#

# Choose from an array of choices by number or value.
# usage: choose_from_list <prompt> <arrayvar> <outvar> <default>
function choose_from_list()
{
	local i=0 choice
	declare -n choices="${2}"

	while [ ${i} -lt "${#choices[@]}" ]
	do
		echo "${i}: ${choices[i]}"
		i=$[i+1]
	done
	IFS= read -p "${1}: " "${3}"
	IFS= read "${3}" <<<"${!3:-"${4}"}"
	if [[ "${!3}" =~ ^[[:digit:]]+$ && 0 -le "${!3}" && "${!3}" -lt "${#choices[@]}" ]]
	then
		IFS= read "${3}" <<<"${choices["${!3}"]}"
		return
	else
		i=0
		while [ "${i}" -lt "${#choices[@]}" ]
		do
			if [ "${!3}" = "${choices[i]}" ]
			then
				return
			fi
			i=$[i+1]
		done
		echo "Bad choice \"${!3}\""
		return 1
	fi
}

# Trim the argument.
# usage: trim varname [outname]
# Take the value stored as "${varname}" and trim
# whitespace from front and back.  If outname is
# given, then store the result in outname.
# Otherwise, store back into varname.
function trim()
{
	local f="${!1}"
	local rtrim="${f##*[![:space:]]}"
	local ltrim="${f%%[![:space:]]*}"
	f="${f#${ltrim}}"
	read "${2:-${1}}" <<<"${f%${rtrim}}"
}

# Take a line of ssh_config and store
# corresponding values into key and value.
function split_entry()
{
	local configline="${1}"
	trim configline key
	configline="${key}"
	key="${configline%%[[:space:]=]*}"
	value="${configline#*"${key}"}"
	trim value
	if [[ "${value::1}" = '=' ]]
	then
		value="${value:1}"
	fi
}

# Split a config file into 2 arrays.
# ssh_hosts: index array of host names.
#            If the first entry is empty, it means the lines
#            are before any HOST config line, like comments etc.
# ssh_data: associative array of host_${host} to a string of the
#           corresponding lines.
function chunk_config()
{
	local ssh_host= key value
	ssh_hosts=("${ssh_host}")
	declare -g -A ssh_data=()
	# NOTE
	# associative arrays MUST use declare -A <varname>
	# As a result, associative arrays must be either local or global
	# cannot create an associative array and have it only visible in
	# parent scope.
	while IFS= read -r line
	do
		if [[ "${line,,}" =~ ^[[:space:]]*host[[:space:]=].*$ ]]
		then
			split_entry "${line}"
			trim value ssh_host
			ssh_hosts+=("${ssh_host}")
		fi
		ssh_data["host_${ssh_host}"]="${ssh_data["host_${ssh_host}"]}${line}
"
	done < "${1:-"${HOME}/.ssh/config"}"
}

# add a new entry to ssh config
# usage: add_entry_option <value>
#   value: the value for the option.  If empty, do nothing.
# assumes caller has defined variables:
#   entry: A string that represents the current ssh config entry
#   ignored: string of ignored lines (comments, blanks, etc)
#   indent: indentation to use for the line.
#   key: the key/option name.
#   value: the original value if any.
function add_entry_option()
{
	if [[ -z "${1}" || "${1}" = '-' ]]
	then
		return
	fi
	if [[ "${1}" =~ ^.*[[:space:]].*$ ]]
	then
		entry="${entry}${ignored}${indent}${key^^} \"${1}\"
"
	else
		entry="${entry}${ignored}${indent}${key^^} ${1}
"
	fi
	ignored=
	if [[ -n "${value}" ]]
	then
		printf '%s%s %s -> %s\n' "${indent}" "${key^^}" "${value}" "${1}"
	else
		printf '+%s%s %s\n' "${indent}" "${key^^}" "${1}"
	fi
}

# Update an existing entry.
# Assume the caller scope has variables:
#   line: a string containing the original line of the entry.
#   entry: A string that represents the current ssh config entry
#   ignored: string of ignored lines (comments, blanks, etc)
#   indent: indentation to use for the line.
#   key: the key/option name.
#   value: the original value if any.
function update_entry_option()
{
	if [[ "${1}" = '-' ]]
	then
		printf -- '-%s\n' "${line}"
		return
	fi
	if [[ -n "${1}" && "${1}" != "${value}" ]]
	then
		add_entry_option "${1}"
	else
		printf '%s\n' "${line}"
		entry="${entry}${ignored}${line}
"
		ignored=
	fi
}

function parse_config_args()
{
	local i=1 username_parsed= host_parsed= hostname_parsed= \
		private_key_parsed= port_parsed=
	while [[ "${i}" -le "${#}" ]]
	do
		case "${!i}" in
			-n)
				norun=(echo)
				outfile=()
				;;
			-username|-host|-hostname|-private_key|-port)
				local argname="${!i}"
				i=$[i+1]
				echo "setting value \"${argname#-}\""
				read -r "${argname#-}" <<<"${!i}"
				read -r "${argname#-}_parsed" <<<"1"
				;;
			*)
				if [[ -z "${configin}" ]]
				then
					configin="${!i}"
				else
					echo "Unrecognized argument \"${!i}\""
					return 1
				fi
				;;
		esac
		i=$[i+1]
	done
	# ------------------------------
	# verify ssh host
	# ------------------------------
	if [ -z "${host_parsed}" ]
	then
		printf "ssh nickname: "
		read host
		if [[ -z "${host}" ]]
		then
			echo "Need an ssh nickname."
			return 1
		fi
	fi

	# ------------------------------
	# verify ssh key
	# ------------------------------
	if [[ -z "${private_key_parsed}" ]]
	then
		readarray -t keys < <(ls "${keydir}")
		if [ "${#keys[@]}" -eq 0 ]
		then
			echo "No keys found in \"${keydir}\""
			exit 1
		elif [ "${#keys[@]}" -gt 1 ]
		then
			choose_from_list 'Choose the key to use' keys private_key "${keys[0]}" || return 1
			printf 'Using key "%s"\n' "${private_key}"
		else
			printf '1 key found: "%s"\n' "${keys[0]}"
			private_key="${keys[0]}"
		fi
	else
		if [[ ! -f "${keydir}/${private_key}/${private_key}" ]]
		then
			echo "Failed to find key \"${private_key}\""
			return 1
		fi
	fi

	# ------------------------------
	# hostname
	# ------------------------------
	if [[ -z "${hostname_parsed}" ]]
	then
		printf 'hostname (actual server name/ip): '
		read hostname
	fi

	# ------------------------------
	# username
	# ------------------------------
	if [[ -z "${username_parsed}" ]]
	then
		printf 'username: '
		read username
	fi

	# ------------------------------
	# port
	# ------------------------------
	if [[ -z "${port_parsed}" ]]
	then
		printf 'port: '
		read port
	fi
}

# Install a key file from key directory into ${HOME}/.ssh/config/keys
# usage: install_keyfile <keydir> <keyname>
#   keydir: The key repository, directory with all keys
#           The structure should be:
#           /keydir
#               /keyname1
#                   keyname1
#                   keyname1.pub
#               /keyname2
#                   keyname2
#                   keyname2.pub
#           where keyname1 is the private key for keyname1 and
#           keyname1.pub is the public key for keyname1 etc.
#   keyname: the name of the key to install
function install_keyfile()
{
	local keydir="${1}" private_key="${2}"
	if [ "${keydir#${HOME}/.ssh/keys/}" = "${keydir}" ]
	then
		"${norun[@]}" mkdir -p "${HOME}/.ssh/keys/${private_key}" || return 1
		if ! "${norun[@]}" cp "${keydir}/${private_key}/${private_key}" "${HOME}/.ssh/keys/${private_key}/${private_key}"
		then
			if [ ! -f "${HOME}/.ssh/keys/${private_key}/${private_key}" ]
			then
				echo "failed to copy key"
				return 1
			fi
		fi
	fi
	"${norun[@]}" chmod 700 "${HOME}/.ssh" "${HOME}/.ssh/keys" "${HOME}/.ssh/keys/${private_key}" || return 1
	"${norun[@]}" chmod 600 "${HOME}/.ssh/keys/${private_key}/${private_key}" || return 1
}

# Touch the config file and ensure proper permissions
function touch_config()
{
	"${norun[@]}" touch "${HOME}/.ssh/config"
	"${norun[@]}" chmod 700 "${HOME}/.ssh" 
	"${norun[@]}" chmod 600 "${HOME}/.ssh/config"
}

# Update an entry with values
# usage: update_entry <host> <hostname> <username> <private_key> <port>
# Expected existing variables:
#   ssh_hosts
#   ssh_data: associative list of ssh host to config entry strs
#
# Update the entry str in ssh_data
function update_entry
{
	local host="${1}" hostname="${2}" username="${3}" private_key="${4}" port="${5}"
	local datakey="${host}" oldentry="${ssh_data["host_${host}"]}"
	local lineidx=0 entry= indent= idonly=yes ignored= trail=
	printf '\n--- editing entry for "%s" ---\n'  "${host}"
	if [[ -n  "${oldentry}" ]]
	then
		while IFS= read -r line
		do
			if [[ "${line}" =~ ^[[:space:]]*#.*$ || "${line}" =~ ^[[:space:]]*$ ]]
			then
				ignored="${ignored}${line}
"
			else
				split_entry "${line}"
				indent="${line%%[![:space:]]*}"
				case "${key,,}" in
					host)
						update_entry_option "${host}"; host=
						;;
					hostname)
						update_entry_option "${hostname}"; hostname=
						;;
					user)
						update_entry_option "${username}"; username=
						;;
					identityfile)
						update_entry_option "%d/.ssh/keys/${private_key}/${private_key}"; private_key=
						;;
					identitiesonly)
						update_entry_option "${value}"; idonly=
						;;
					port)
						update_entry_option "${port}"; port=
						;;
					*)
						entry="${entry}${ignored}${line}
"
						printf '%s\n' "${line}"
						ignored=
						;;
				esac
			fi
		done <<<"${oldentry%$'\n'}"
	else
		ssh_hosts=("${datakey}" "${ssh_hosts[@]}")
	fi
	indent=
	trail="${ignored}"
	ignored=
	value=
	key=HOST; add_entry_option "${host}"
	indent='	'
	key=HOSTNAME; add_entry_option "${hostname}"
	key=USER; add_entry_option "${username}"
	key=IDENTITYFILE; add_entry_option "${private_key:+"%d/.ssh/keys/${private_key}/${private_key}"}"
	key=PORT; add_entry_option "${port}"
	key=IDENTITIESONLY; add_entry_option "${idonly}"
	ssh_data["host_${datakey}"]="${entry}${trail}"
}

# Dump the config file.
# usage: dump_config [outfile]...
# Expect defined variables:
# ssh_hosts: array of ssh host names
# ssh_data: associative array of ssh config entry data per host
function dump_config()
{
	printf '\n--- %s ---\n' 'config file'
	for k in "${ssh_hosts[@]}"
	do
		printf '%s' "${ssh_data["host_${k}"]}"
	done | tee "${@}"
}

function install_key_config()
{
	local keys=() norun=() outfile=("${HOME}/.ssh/config")
	local configin= host= private_key= hostname= username= port=
	local keydir="${1}"
	shift 1
	parse_config_args "${@}" || return 1
	install_keyfile "${keydir}" "${private_key}" || return 1
	chunk_config "${configin}"
	update_entry "${host}" "${hostname}" "${username}" "${private_key}" "${port}"
	dump_config "${outfile[@]}"
}

function simple_key_config()
{
	local keys=() norun=() outfile=("${HOME}/.ssh/config") i=1
	local configin= host= private_key=() hostname= username= port=
	local keydir="${1}"
	shift 1

	local port_parsed= username_parsed= hostname_parsed=
	while [[ "${i}" -le "${#}" ]]
	do
		case "${!i}" in
			-n)
				norun=(echo)
				outfile=()
				;;
			-private_key)
				i=$[i+1]
				while [[ "${!i}" =~ ^[^-].*$ ]]
				do
					private_key+=("${!i}")
					i=$[i+1]
				done
				continue
				;;
			-username|-hostname|-port)
				local argname="${!i}"
				i=$[i+1]
				echo "setting value \"${argname#-}\""
				read -r "${argname#-}" <<<"${!i}"
				read -r "${argname#-}_parsed" <<<"1"
				;;
			*)
				if [[ -z "${configin}" ]]
				then
					configin="${!i}"
				else
					echo "Unrecognized argument \"${!i}\""
					return 1
				fi
				;;
		esac
		i=$[i+1]
	done

	if [[ -z "${hostname}" ]]
	then
		printf 'hostname (actual ip/url): '
		read hostname
	fi
	if [[ -z "${username}" ]]
	then
		printf 'username: '
		read username
	fi
	if [[ -z "${port_parsed}" ]]
	then
		printf 'port: '
		read port
	fi

	if [[ "${#private_key[@]}" -eq 0 ]]
	then
		readarray -t private_key < <(ls "${keydir}")
	fi

	echo "config in: ${configin}"
	echo "hostname: ${hostname}"
	echo "user: ${username}"
	echo "port: ${port}"

	printf 'keys:\n'
	printf '\t%s\n' "${private_key[@]}"

	"${norun[@]}" mkdir -p "${private_key[@]/#/${HOME}/.ssh/keys/}" || return 1
	local keyfiles=()
	for keyname in "${private_key[@]}"
	do
		if ! "${norun[@]}" cp "${keydir}/${keyname}/${keyname}" "${HOME}/.ssh/keys/${keyname}/${keyname}"
		then
			if [[ ! -f "${HOME}/.ssh/keys/${keyname}/${keyname}" ]]
			then
				echo "Failed to copy key \"${keyname}\""
				return 1
			fi
		fi
		keyfiles+=("${HOME}/.ssh/keys/${keyname}/${keyname}")
	done
	"${norun[@]}" chmod 700 "${HOME}/.ssh" "${private_key[@]/#/${HOME}/.ssh/keys/}" || return 1
	"${norun[@]}" chmod 600 "${keyfiles[@]}" || return 1
	chunk_config "${configin}"
	for keyname in "${private_key[@]}"
	do
		update_entry "${keyname}" "${hostname}" "${username}" "${keyname}" "${port}"
	done
	dump_config "${outfile[@]}"
	if [[ "${#outfile[@]}" -gt 0 ]]
	then
		"${norun[@]}" chmod 600 "${outfile[@]}"
	fi
}

# set bits argument depending on ssh key type
function get_bits()
{
	case "${1}" in
		dsa)
			bits=(-b 1024)
			;;
		rsa)
			printf "number of bits? (min 1024, default 3072): "
			read bits
			if ! [[ "${bits}" =~ ^[0-9]+$ ]]
			then
				echo "Bad bit value, must be numeric."
				return 1
			elif [ "${bits:-3072}" -lt 1024 ]
			then
				bits=(-b 1024)
			else
				bits=(-b "${bits:-3072}")
			fi
			;;
		ecdsa)
			choices=(256 384 521)
			choose_from_list 'bit value' choices bits 521 || return 1
			bits=(-b "${bits}")
			;;
		*)
			bits=()
	esac
}

# Create an ssh key interactively.
function create_sshkey()
{
	local outname outdir outkey type bits=() TYPES keydir create=()
	keydir="${1}"
	shift 1

	if [[ "${1}" == '-n' ]]
	then
		create=(echo)
		shift 1
	fi

	printf "new key name: "
	read outname
	if [[ "${outname}" =~ ^.*/.*$ ]]
	then
		echo "outname should be name, not a path."
		return 1
	elif [[ -z "${outname}" ]]
	then
		echo 'canceled'
		return 1
	fi

	outdir="${keydir}/${outname}"
	if [ -d "${outdir}" ]
	then
		echo "Name \"${outname}\" already exists."
		return 1
	fi
	TYPES=(dsa ecdsa ecdsa‐sk ed25519 ed25519‐sk rsa)
	choose_from_list 'key type (default: ed25519)' TYPES type ed25519 || return 1
	echo "creating key type \"${type}\""
	get_bits "${type}" || return 1

	if [[ "${#create[@]}" = 0 ]]
	then
		if ! mkdir -p "${outdir}"
		then
			echo "failed to create directory \"${outdir}\"."
			return 1
		fi
	fi
	hash ssh-keygen
	outkey="${outdir}/${outname}"
	if [[ "$(hash -t ssh-keygen)" =~ ^'/cygdrive/'.*$ ]]
	then
		outkey="$(cygpath -w ${outkey})"
		echo "fixed cygwin path to \"${outkey}\""
	fi
	"${create[@]}" ssh-keygen -t "${type}" "${bits[@]}" -f "${outkey}" "${@}"
}

function help_message()
{
	cat << EOF
usage: run.sh [-l] command
  options:
    -l: Use "${HOME}/.ssh/keys" as the default key directory.
        Otherwise, save to same directory as this script.
  commands:
    -------
    i: install a key to ssh config file
      i [-n] [configfile] [args]...
        -n: just print, do not actually run.
        configfile: default to ${HOME}/.ssh/config
      You will be prompted for basic ssh config entry fields.
      Leave blank to keep the value that already exists.  Use a single
      '-' to delete the existing entry.  Otherwise enter a value.

      extra arguments:
        -username <user>        The ssh user.
        -host <host>            The host (nickname) for the ssh.
                                You would ssh by \`ssh <host>\` or clone
                                with \`git clone <host>:owner/repo.git\`.
        -hostname <hostname>    The hostname, or the actual server url/ip.
        -private_key <key>      The name of the key to use.
        -port <port>            The port to use.

    ------
    s: Simple install of multiple keys.  This is similar to the i
       command.  -private_key will take multiple keys.  Each key
       will use host identical to the key name.  The hostname,
       username, and port will apply to all keys.  If not specified,
       then all keys in the repository will be installed.
    ------
    c: create a new ssh key.
      create [-n] [args]...
        -n: just print the command, do not actually run
        args: extra arguments for ssh-keygen.
        notable arguments:
          -C \"comment about what the key is for\"
EOF
}


function main()
{
	if [ "${1}" = '-l' ]
	then
		keydir="${HOME}/.ssh/keys"
		shift 1
	else
		keydir="$(dirname "${BASH_SOURCE[0]}")/keys"
	fi
	keydir="$(realpath "${keydir}")"
	if [[ "${1::1}" = '-' ]]
	then
		cmd=c
	else
		cmd="${1:-c}"
		shift 1
	fi
	case "${cmd}" in
		i)
			install_key_config "${keydir}" "${@}"
			exit $?
			;;
		s)
			simple_key_config "${keydir}" "${@}"
			exit $?
			;;
		c)
			create_sshkey "${keydir}" "${@}"
			exit $?
			;;
		*)
			help_message
			;;
	esac
}

main "${@}"
