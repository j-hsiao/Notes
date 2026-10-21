#!/bin/bash
# Temporarily bind a directory.
# Wait until stdin/exit to unbind.


if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	targets=()
	while (($#))
	do
		case "${1}" in
			-h|--help)
				local msg='usage: tbind [-h] [src dst]...

				Bind sources at destinations.  Arguments are alternating source and
				destination dirs.
				'
				echo "${msg//$'\t'}" >&2
				exit
				;;
			*) targets+=("${1}") ;;
		esac
		shift
	done
	if [[ "${USER}" != root ]]
	then
		sudo bash "${BASH_SOURCE[0]}" "${targets[@]}"
		exit
	fi
	tbind()
	{
		local targets=("${@}")
		local dsts=() inp item
		trap 'trap - RETURN; for item in "${dsts[@]}"; do umount "${item}"; done' RETURN
		while true
		do
			echo 'mounting'
			local idx
			for ((idx=1; idx<${#targets[@]}; idx+=2))
			do
				echo "  ${targets[idx-1]} @ ${targets[idx]}"
				mount "${targets[@]:idx-1:2}" -o bind || { echo 'mount error'; return 1; }
				dsts+=("${targets[idx]}")
			done
			read -p 'Press enter to continue.' inp
			echo 'umounting'
			while (("${#dsts[@]}"))
			do
				echo "  ${dsts[-1]}"
				umount "${dsts[-1]}" && unset dsts[-1] || { echo 'umount error'; return 1; }
			done
			{ read -p 'Remount? (y/n): ' -r inp && [[ "${inp}" != n* ]]; } || return
		done
	}
	tbind "${targets[@]}"
else
	if [[ "${BASH_SOURCE[0]}" != /* ]]
	then
		. "${PWD}/${BASH_SOURCE[0]}" "${@}"
	else
		tbind () { bash "${BASH_SOURCE[0]}" "${@}"; }
	fi
fi
