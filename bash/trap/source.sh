#!/bin/bash

# Sourcing interaction with traps

if [[ "${1}" != 'sourcing' ]]
then
	fun()
	{
		local INDENT="${INDENT}  "

		if [[ -n "${1}" ]]
		then
			trap return ERR
		fi
		if [[ -n "${2}" ]]
		then
			trap 'echo "return trap activated ${#BASH_SOURCE[@]} | ${#FUNCNAME[@]} | ${BASH_COMMAND} | ${SHLVL}"; trap - ERR RETURN' RETURN
		fi

		printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '1------------------------------' '' "BASH_COMMAND is ${BASH_COMMAND}" '' "SHLVL is ${SHLVL}"
		trap -p | xargs -d '\n' -n 1 printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" ''
		printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '1------------------------------'
		. "${BASH_SOURCE[0]}" 'sourcing'
		(($?==0))||return 1

		echo "    source code: $?"
		printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '2------------------------------'
		trap -p | xargs -d '\n' -n 1 printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" ''
		printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '2------------------------------'
	}


	indent=''
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '1------------------------------'
	trap -p | xargs -d '\n' -n 1 printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" ''
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '1------------------------------'
	fun "${@}"
	echo "  fun code: $?"
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '2------------------------------'
	trap -p | xargs -d '\n' -n 1 printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" ''
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '2------------------------------'
else
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '1------------------------------'
	trap -p | xargs -d '\n' -n 1 printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" ''
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '1------------------------------'

	echo "      sourced bash_source len is ${#BASH_SOURCE[@]}"
	false

	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '2------------------------------'
	trap -p | xargs -d '\n' -n 1 printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" ''
	printf "%$((${#BASH_SOURCE[@]}*2))s%s\\n" '' '2------------------------------'
fi
