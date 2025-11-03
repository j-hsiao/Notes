#!/bin/bash

permute() # <array> <out>
{
	if (($# < 3 ))
	then
		local -n permute__arr="${1}"
		local -n permute__out="${2:-OUT}"
		permute__out=()
		local choices=("${permute__arr[@]}")
	fi
	local idx="${3:-0}"
	if ((idx < ${#choices[@]}-1))
	then
		local pick="${idx}"
		while ((pick < ${#choices[@]}))
		do
			local tmp="${choices[idx]}"
			choices[idx]="${choices[pick]}"
			choices[pick]="${tmp}"
			permute "${1}" '' "$((idx+1))"
			choices[pick]="${choices[idx]}"
			choices[idx]="${tmp}"
			((++pick))
		done
	else
		printf -v permute__out[${#permute__out[@]}] '<%s>' "${choices[@]^}"
	fi
}

do_search() # prefix target
{
	while read schema
	do
		if [[ "${schema}" = "${1}"* ]]
		then
			local result="$(gsettings list-recursively "${schema}" | grep --color=always "${2}")"
			if [[ -n "${result}" ]]
			then
				echo "${schema}"
				echo "  ${result//$'\n'/$'\n  '}"
			fi
		fi
	done < <(gsettings list-schemas)
}

do_keybinds() # prefix [modifiers...] key
{
	local prefix="${1}"
	shift
	local modifiers=()
	while (($# > 1))
	do
		local key="${1,,}"
		modifiers+=("${key^}")
		shift
	done
	local key="${1}"

	if ((${#modifiers[@]}))
	then
		local mods
		permute modifiers mods
		local query=
		printf -v query "'%s${key}'"'\\|' "${mods[@]}"
		query="${query:0:-2}"
	else
		local query="'${key}'"
	fi

	while read schema
	do
		if [[ "${schema}" = "${prefix}"* ]]
		then
			settings="$(gsettings list-recursively "${schema}" | grep --color=always "${query}")"
			if [[ -n "${settings}" ]]
			then
				echo "found in ${schema}"
				echo "  ${settings//$'\n'/$'\n  '}"
			fi
		fi
	done < <(gsettings list-schemas)
}

run() {
	local cmd=
	local args=()
	local prefix='org.gnome'
	while (($#))
	do
		case "${1}" in
			-h|--help)
				echo "usage: keybinds.sh [-h] [-p prefix] <command>
				general arguments:
				    [-h|--help]
				        show the help message
				    [-p|--prefix] prefix=org.gnome
				        The prefix of schemas to check.
				commands:
				    search query
				        search for query anywhere in schemas
				    keybinds [modifiers...] key
				        search for specific keybinds
				" | sed 's/^\t*//'
				return
				;;
			-p|--prefix)
				shift
				prefix="${1}"
				;;
			search|keybinds)
				cmd="${1}"
				;;
			*)
				if [[ -z "${cmd}" ]]
				then
					echo "Unknown command \"${1}\""
					run -h
					return 1
				else
					args+=("${1}")
				fi
		esac
		shift
	done
	"do_${cmd}" "${prefix}" "${args[@]}"
}

run "${@}"
