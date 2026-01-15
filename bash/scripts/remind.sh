#!/bin/bash


if [[ "${BASH_SOURCE[0]}" != /* ]]
then
	. "${PWD}/${BASH_SOURCE[0]}"
else
	if [[ -d /cygdrive ]]
	then
		remind__='-n:env TZ='
	else
		remind__=
	fi
	remind__='remind() {
		local pyscript="${BASH_SOURCE[0]/%remind.sh/../../python/tk/remind.py}"
		if ! PYEXE "${pyscript}" '"${remind__%%:*}"' "${@}"
		then
			nohup '${remind__##*:}' PYEXE "${pyscript}" launch &>/dev/null
			PYEXE "${pyscript}" "${@}"
		fi
	}'

	for remind__PYEXE in py python3 python
	do
		if type -P "${remind__PYEXE}" &>/dev/null
		then
			eval "${remind__//PYEXE/${remind__PYEXE@Q}}"
			unset remind__ remind__PYEXE
			break
		fi
	done
fi
