#!/bin/bash

alias to=cd

function to_() {
	local resets=() local opt

	for opt in nullglob extglob
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
	COMPREPLY=(
		/cygdrive/"${query}"*/
		'//wsl$/ubuntu/home/'"${USER}"/"${query}"*/
		"${query}"*/
	)
	[[ -n "${chosen}" ]] && COMPREPLY=("${COMPREPLY[chosen]}")
}
complete -F to_ -o nospace to
