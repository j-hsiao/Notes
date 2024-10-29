#!/bin/bash

# numbering starts from one so position 0 will just be the current
# search
numeric_completion_choices=()
alias n=''
num_complete() {
	local extra="${2#${numeric_completion_choices[0]}}"

	if [[ "${extra}" != "${2}" && "${extra}" =~ ^[0-9]+$ && "${extra}" -lt "${#numeric_completion_choices[@]}" ]]
	then
		COMPREPLY=("${numeric_completion_choices[extra]}")
		numeric_completion_choices=()
	else
		numeric_completion_choices=("${2}")
		local tmp
		readarray -O 1 -t tmp < <(compgen -o filenames -o nospace -f "${2}")
		if [[ "${#tmp[@]}" -eq 1 ]]
		then
			COMPREPLY=("${tmp[0]}")
		else
			if [[ "${#tmp[@]}" -gt 1 ]]
			then
				printf '%s\n' "${tmp[@]}" | cat -n | column | less
			fi
			numeric_completion_choices+=("${tmp[@]}")
			COMPREPLY=()
		fi
	fi
}
complete -o nospace -o filenames -F num_complete n
