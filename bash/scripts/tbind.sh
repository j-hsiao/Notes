#!/bin/bash
# Temporarily bind a directory.
# Wait until stdin/exit to unbind.


if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	src="${1%/}"
	dst="${2:-${src##*/}}"
	if mount "${src}" "${dst}" -o bind
	then
		trap 'trap - EXIT; umount "${dst}"' EXIT
		echo "Mounted ${src} at ${dst}..."
		printf "Press enter to cancel..."
		read
	fi
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

