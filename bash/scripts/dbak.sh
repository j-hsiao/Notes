#!/bin/bash
dbak() {
	local dname
	local dnames=()
	local dryrun=
	local bakdir=.
	[[ -f .bak ]] && read -r bakdir <.bak

	if ! shopt extglob &>/dev/null
	then
		shopt -s extglob
		trap 'trap - RETURN; shopt -u extglob' RETURN
	fi

	while (($#))
	do
		case "${1}" in
			-d|--dryrun)
				dryrun=echo
				;;
			-b|--bak)
				shift
				bakdir="${1%%+(/)}"
				;;
			-h|--help)
				msg='dbak [-d] [-h] [-b bak]
				-d|--dryrun: dryrun
				-h|--help: print this help message
				-b|--bak bakdir: specify destination of backup.'
				echo "${msg//$'\t'/}"
				return
				;;
			*)
				dnames+=("${1%%+(/)}")
				;;
		esac
		shift
	done

	for dname in "${dnames[@]}"; do
		if [[ -d "${dname}/.git" ]]
		then
			cd "${dname}"
			${dryrun} git push origin master
			cd "${OLDPWD}"
		else
			local name="${dname##*/}"
			while read -r -d '' fname
			do
				bak="${bakdir}/${name}/${fname#"${dname}/"}"
				if [[ "${fname}" -ef "${bak}" ]]
				then
					echo "Same source and target file, did you forget to specify backup dir?"
					return 1
				fi

				if ! diff "${fname}" "${bak}" >&/dev/null
				then
					echo "${fname}"
					if ! [[ -d "${bak%/*}" ]]
					then
						${dryrun} mkdir -p "${bak%/*}"
					fi
					${dryrun:+:} cp "${fname}" "${bak}"
				fi
			done < <(find "${dname}" -type f -print0)
		fi
	done
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	dbak "${@}"
fi
