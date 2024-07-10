#!/bin/bash
# manage ssh keys


function enumerate()
{
	local i=0
	while [ ${i} -lt "${#}" ]
	do
		i=$[i+1]
		echo "$[i-1]: ${!i}"
	done
}
if [ "${1}" = '-l' ]
then
	KEYDIR="${HOME}/.ssh/keys"
else
	KEYDIR="$(dirname "${BASH_SOURCE[0]}")/keys"
fi
KEYDIR="$(realpath "${KEYDIR}")"

case "${1:-create}" in
	install)
		shift 1
		printf "ssh nickname: "
		read host
		readarray -t keys < <(ls "${KEYDIR}")

		if [ "${#keys[@]}" -eq 0 ]
		then
			echo "No keys found in \"${KEYDIR}\""
			exit 1
		elif [ "${#keys[@]}" -gt 1 ]
		then
			enumerate "${keys[@]}"
			printf "Choose the key to use: "
			read key
			if [[ "${key}" =~ [0-9]+ ]]
			then
				key="${keys[key]}"
			fi
		else
			echo "only 1 key found"
			echo "using \"${keys[0]}\""
			key="${keys[0]}"
		fi

		if [ "${KEYDIR#${HOME}/.ssh/keys/}" = "${KEYDIR}" ]
		then
			mkdir -p "${HOME}/.ssh/keys/${key}"
			if ! cp -r "${KEYDIR}/${key}/${key}" "${HOME}/.ssh/keys/${key}"
			then
				if [ ! -f "${HOME}/.ssh/keys/${key}" ]
				then
					echo "failed to copy key"
					exit 1
				fi
			fi
		fi

		printf 'hostname (actual server name/ip, default to nickname): '
		read hostname

		printf 'username: '
		read username

		printf 'port: '
		read port
		if [ -z "${port}" ]
		then
			port=()
		else
			port=(PORT "${port}")
		fi
		cat << EOF
HOST ${host}
	USER ${username:-${USER}}
	HOSTNAME ${hostname:-host}
	IDENTITYFILE ${HOME}/.ssh/keys/${key}/${key}
	IDENTITIESONLY yes
	${port[@]}
EOF

		;;
	create)
		shift 1
		printf "key name: "
		read outname
		if [ "${outname##*/}" != "${outname}" ]
		then
			echo "outname should be name, not a path."
			exit 1
		fi
		outname="${KEYDIR}/${outname}"
		if [ -d "${outname}" ]
		then
			echo "Name \"${outname##*/}\" already exists."
			exit 1
		fi
		if ! mkdir -p "${outname}"
		then
			echo "failed to create directory \"${outname}\"."
			exit 1
		fi
		outname="${outname}/${outname##*/}"

		TYPES=(dsa ecdsa ecdsa‐sk ed25519 ed25519‐sk rsa)
		enumerate "${TYPES[@]}"
		printf "key type (default ed25519): "
		read type
		if [[ "${type:-3}" =~ [0-9]* ]]
		then
			type="${TYPES[${type:-3}]}"
		fi
		type=${type,,}

		case "${type}" in
			dsa)
				bits=(-b 1024)
				;;
			rsa)
				printf "number of bits? (min 1024, default 3072): "
				read bits
				if [ "${bits:-3072}" -lt 1024 ]
				then
					bits=(-b 1024)
				else
					bits=(-b "${bits:-3072}")
				fi
				;;
			ecdsa)
				choices=(256 384 521)
				enumerate "${choices[@]}"
				printf "bit value: "
				read bits
				if [ -z "${bits}" ]
				then
					bits=(-b 521)
				elif [ -z "${choices[bits]}" ]
				then
					if [[ "${bits}" =~ [0-9]+ ]]
					then
						for b in "${choices[@]}"
						do
							if [ "${bits}" -le "${b}" ]
							then
								bits=(-b "${b}")
								break
							fi
						done
						if [ "${#bits[@]}" -lt 2 ]
						then
							bits=(-b 521)
						fi
					else
						echo "bad bit value: \"${bits}\""
						exit 1
					fi
				else
					bits=(-b "${choices[bits]}")
				fi
				;;
			*)
				bits=()
		esac
		ssh-keygen -t "${type}" "${bits[@]}" -f "${outname}" "${@}"
		;;
	*)
		cat << EOF
usage: run.sh command
  commands:
    --------------
    install
    --------------
      install a key to ${HOME}/.ssh/config

    -----------------------
    create [args]...
    -----------------------
      create a new ssh key.

      Extra arguments are just extra args for ssh-keygen
      notable extra arguments:
        -C \"comment about what the key is for\"
EOF
		;;
esac
