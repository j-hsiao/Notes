#!/bin/bash
# manage ssh keys

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
			echo "switched ssh_host to \"${ssh_host}\""
		fi
		ssh_data["host_${ssh_host}"]="${ssh_data["host_${ssh_host}"]}${line}
"
	done < "${1:-"${HOME}/.ssh/config"}"
}

# add a new entry to ssh config
# usage: add_entry_value <value>
#   value: the value for the option.  If empty, do nothing.
# assumes caller has defined variables:
#   entry: A string that represents the current ssh config entry
#   ignored: string of ignored lines (comments, blanks, etc)
#   indent: indentation to use for the line.
#   key: the key/option name.
#   value: the original value if any.
function add_entry_value()
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
function update_entry()
{
	if [[ "${1}" = '-' ]]
	then
		printf -- '-%s\n' "${line}"
		return
	fi
	if [[ -n "${1}" && "${1}" != "${value}" ]]
	then
		add_entry_value "${1}"
	else
		printf '%s\n' "${line}"
		entry="${entry}${ignored}${line}
"
		ignored=
	fi
}


function install_key()
{
	local keys=() norun=() outfile=("${HOME}/.ssh/config")
	KEYDIR="${1}"
	shift 1
	if [[ "${1}" = '-n' ]]
	then
		norun=(echo)
		outfile=()
		shift 1
	fi
	printf "ssh nickname: "
	read host
	if [[ -z "${host}" ]]
	then
		echo "Need an ssh nickname."
		return 1
	fi

	readarray -t keys < <(ls "${KEYDIR}")
	if [ "${#keys[@]}" -eq 0 ]
	then
		echo "No keys found in \"${KEYDIR}\""
		exit 1
	elif [ "${#keys[@]}" -gt 1 ]
	then
		choose_from_list 'Choose the key to use' keys private_key "${keys[0]}" || return 1
		printf 'Using key "%s"\n' "${private_key}"
	else
		printf '1 key found: "%s"\n' "${keys[0]}"
		private_key="${keys[0]}"
	fi

	if [ "${KEYDIR#${HOME}/.ssh/keys/}" = "${KEYDIR}" ]
	then
		"${norun[@]}" mkdir -p "${HOME}/.ssh/keys/"
		if ! "${norun[@]}" cp "${KEYDIR}/${private_key}/${private_key}" "${HOME}/.ssh/keys/${private_key}"
		then
			if [ ! -f "${HOME}/.ssh/keys/${private_key}" ]
			then
				echo "failed to copy key"
				return 1
			fi
		fi
	fi
	"${norun[@]}" touch "${HOME}/.ssh/config"
	"${norun[@]}" chmod 700 "${HOME}/.ssh" "${HOME}/.ssh/keys"
	"${norun[@]}" chmod 600 "${HOME}/.ssh/config" "${HOME}/.ssh/keys/${private_key}"

	printf 'hostname (actual server name/ip): '
	read hostname
	printf 'username: '
	read username
	printf 'port: '
	read port

	chunk_config "${@}"
	local datakey="${host}" oldentry="${ssh_data["host_${host}"]}"
	local lineidx=0 entry= indent= idonly=yes ignored= trail=
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
						update_entry "${host}"
						host=
						;;
					hostname)
						update_entry "${hostname}"
						hostname=
						;;
					user)
						update_entry "${username}"
						username=
						;;
					identityfile)
						update_entry "%d/.ssh/keys/${private_key}"
						private_key=
						;;
					identitiesonly)
						update_entry "${value}"
						idonly=
						;;
					port)
						if [[ -n "${port}" ]]
						then
							update_entry "${port}"
						else
							entry="${entry}${ignored}${line}
"
							printf '%s\n' "${line}"
							ignored=
						fi
						port=
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
	key=HOST; value=; add_entry_value "${host}"
	indent='	'
	key=HOSTNAME; value=${datakey}; add_entry_value "${hostname}"
	key=USER; value=; add_entry_value "${username}"
	key=IDENTITYFILE; value=; add_entry_value "${private_key:+"%d/.ssh/keys/${private_key}"}"
	key=PORT; value=; add_entry_value "${port}"
	key=IDENTITIESONLY; value=; add_entry_value "${idonly}"
	ssh_data["host_${datakey}"]="${entry}${trail}"

	printf '%s\n' '--- config file ---'
	for k in "${ssh_hosts[@]}"
	do
		printf '%s' "${ssh_data["host_${k}"]}"
	done | tee "${outfile[@]}"
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
	local outname outdir outkey type bits=() TYPES KEYDIR create=()
	KEYDIR="${1}"
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

	outdir="${KEYDIR}/${outname}"
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
      i [-n] [configfile]
        -n: just print, do not actually run.
        configfile: default to ${HOME}/.ssh/config
      You will be prompted for basic ssh config entry fields.
      Leave blank to keep the value that already exists.  Use a single
      '-' to delete the existing entry.  Otherwise enter a value.
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
		KEYDIR="${HOME}/.ssh/keys"
		shift 1
	else
		KEYDIR="$(dirname "${BASH_SOURCE[0]}")/keys"
	fi
	KEYDIR="$(realpath "${KEYDIR}")"
	if [[ "${1::1}" = '-' ]]
	then
		cmd=c
	else
		cmd="${1:-c}"
		shift 1
	fi
	case "${cmd}" in
		i)
			install_key "${KEYDIR}" "${@}"
			;;
		c)
			create_sshkey "${KEYDIR}" "${@}"
			exit $?
			;;
		*)
			help_message
			;;
	esac
}

main "${@}"
