#!/bin/bash
# As far as I can tell, this seems to be the best way to handle sourced
# files inconjunction with traps to reset traps for the caller.

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	fun()
	{
		trap 'echo "fun return trap: ${BASH_SOURCE[*]} | ${FUNCNAME[*]}"' RETURN
		echo "in fun ${BASH_SOURCE[*]} | ${FUNCNAME[*]}"
		local x
		. "${BASH_SOURCE[0]/v.sh/.\/v.sh}"
		((! (x = $?))) || return $x
	}

	echo "nsource ${BASH_SOURCE[*]} | ${FUNCNAME[*]}"
	fun "${@}" && echo success || echo fail
	trap - RETURN
else
	echo "inside source... ${BASH_SOURCE[*]} | ${FUNCNAME[*]}"

	echo "${@}"
	return "${1:-0}"
fi
