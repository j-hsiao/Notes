#!/bin/bash

alias to=cd

TO_SHORTCUTS=("${TO_SHORTCUTS[@]}")

function to_() {
	local resets=() local opt
	for opt in nullglob extglob nocaseglob
	do
		[[ "${BASHOPTS}" != *"${opt}"* ]] && resets+=("${opt}")
	done
	if (("${#resets[@]}"))
	then
		shopt -s "${resets[@]}"
		trap 'trap - RETURN; shopt -u "${resets[@]}"' RETURN
	fi

	local query="${2}" chosen=
	if [[ "${query}" = *,?(-)+([0-9]) ]]
	then
		chosen="${query##*,}"
		query="${query%,*}"
	fi
	if [[ "${query}" = '~'* ]]
	then
		query="${query/#'~'/"${HOME}"}"
	fi
	COMPREPLY=()
	if [[ "${query}" != /*  && "${query}" != .* ]]
	then
		if [[ oldpwd = "${query,,}"* ]]
		then
			COMPREPLY+=('"${OLDPWD}"')
		fi
		for item in "${TO_SHORTCUTS[@]}"
		do
			if [[ "${item}" = "${query}"* ]]
			then
				COMPREPLY+=("${item#*:}")
			fi
		done
		local dname
		for dname in '/cygdrive/' '/mnt/' "/run/media/${USER}/" '//wsl$/ubuntu/home/'*/
		do
			if [[ -d "${dname}" ]]
			then
				COMPREPLY+=("${dname%/}/${query}"*/)
			fi
		done
	fi
	COMPREPLY+=("${query}"*/)

	if [[ -n "${chosen}" ]]
	then
		local pick="${COMPREPLY[chosen-1]}"
		if [[ "${pick}" != '"'* ]]
		then
			printf -v pick '%q' "${pick}"
		fi
		COMPREPLY=("${pick}")
	fi

	if (("${#COMPREPLY[@]}">1))
	then
		local i=0
		if (("${#COMPREPLY[@]}">"${LINES}"))
		then
			for ((i=1; i<=${#COMPREPLY[@]}; ++i)); do printf '%2d: %s\n' "${i}" "${COMPREPLY[i-1]}"; done | less
			COMPREPLY=()
		else
			for ((i=1; i<=${#COMPREPLY[@]}; ++i)); do printf '\n%2d: %s' "${i}" "${COMPREPLY[i-1]}"; done
			COMPREPLY=('' ' ')
		fi
	fi
}
complete -F to_ -o nospace to
