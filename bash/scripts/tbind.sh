#!/bin/bash
# Temporarily bind a directory.
# Wait until stdin/exit to unbind.


if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	tbind()
	{
		local src="${1%/}"
		local dst="${2:-${src##*/}}"
		shift 2
		if mount "${src}" "${dst}" -o bind
		then
			trap 'trap - RETURN; umount "${dst}"' RETURN
			echo "Mounted ${src} at ${dst}..."
			if (($#))
			then
				tbind "${@}"
			else
				printf "Press enter to cancel..."
				read
			fi
		fi
	}
	tbind "${@}"
else
	if [[ "${BASH_SOURCE[0]}" = /* ]]
	then
		tbind() # src dst
		{
			if [[ "${USER}" != root ]]
			then
				local pre=sudo
			else
				local pre=
			fi
			${pre} bash "${BASH_SOURCE[0]}" "${@}"
		}
	else
		. "${PWD}/${BASH_SOURCE[0]}" "${@}"
	fi
fi

