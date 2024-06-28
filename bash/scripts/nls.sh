#!/bin/bash

# enumerate corresponding items and save to an array.
nls_search_cache=()
function nls()
{
	local fnames=() defaults=(-type d) numcols=0 flags=()
	while [ "${#}" -gt 0 -a "${1:0:1}" != '-' ]
	do
		fnames+=("${1}")
		shift
	done
	while [ "${#}" -gt 0 ]
	do
		if [[ "${1}" = '-h' ]]
		then
			echo 'same arguments as find. but forces min/maxdepth 1'
			echo 'defaults to: -type d'
			echo 'use -A to change default to: -type d -o -type f'
			return
		elif [[ "${1}" = '-A' ]]
		then
			flags+=(-type d -o -type f)
		elif [[ "${1}" =~ -[0-9]+ ]]
		then
			numcols="${1#-}"
		else
			flags+=("${1}")
		fi
		shift
	done
	local enumerate=(nl -s ' ' -w 1 -n 'ln')
	if [ "${numcols}" -gt 0 ] || ! hash column >/dev/null 2>&1
	then
		local columnate=(pr "-${numcols}" -t -w $(tput cols))
	else
		local columnate=(column)
	fi
	readarray -t nls_search_cache < \
		<(find "${fnames[@]}" -maxdepth 1 -mindepth 1 "${flags[@]:-${defaults[@]}}" | sort)
	printf '%s\n' "${nls_search_cache[@]##*/}" | "${enumerate[@]}" | "${columnate[@]}"
}

# pick a number from the last nls command and run a command on it
# optionally add a command to perform on the chosen item.
function np()
{
	local num= printall=0 default=(printf '%s') cmd=()
	while [ "${#}" -gt 0 ]
	do
		if [ "${1}" = d ]
		then
			shift
			local enumerate=(nl -s ' ' -w 1 -n 'ln')
			if [[ "${1}" =~ -[0-9]+ ]] || ! hash column >/dev/null 2>&1
			then
				local columnate=(pr "${1}" -t -w $(tput cols))
			else
				local columnate=(column)
			fi
			printf '%s\n' "${nls_search_cache[@]##*/}" | "${enumerate[@]}" | "${columnate[@]}"
		elif [ "${1}" = '-a' ]
		then
			printall=1
		elif [[ "${1}" =~ [0-9]+ && -z "${num}" ]]
		then
			num="${1}"
		else
			cmd+=("${1}")
		fi
		shift
	done
	if [ "${printall}" -gt 0 ]
	then
		"${cmd[@]:-${default[@]}}" "${nls_search_cache[num-1]}"
	else
		"${cmd[@]:-${default[@]}}" "${nls_search_cache[num-1]##*/}"
	fi
}
