#!/bin/bash

# Check for free keys without any bindings.
# NOTE: if tmux is started this is faster
# Otheriwse, tmux needs to parse the configs
# between each invocation.

extract_tables() # info [out=tables]
{
	local -n et__info="${1}"
	local -n et__tables="${2:-tables}"
	local et__line
	et__tables=()
	for et__line in "${et__info[@]}"
	do
		if [[ "${et__line}" =~ ^'bind-key'[[:blank:]]*[-r]*[[:blank:]]*'-T'[[:blank:]]*([^[:blank:]]*) ]]
		then
			local et__table="${BASH_REMATCH[1]}"
			if [[ " ${et__tables[*]} " != *" ${et__table} "* ]]
			then
				et__tables+=("${et__table}")
			fi
		fi
	done
}

check_table() # info [tablename=prefix]
{
	# Find all the free keys for the given table
	# and tmux list-keys line array.
	local -n info="${1}"
	local table="${2:-prefix}"
	local prefixes=('C-' 'S-' 'M-')
	local names=(
		Up Down Left Right BSpace BTab DC End
		Enter Escape F{1..12} Home
		IC NPage PPage Space Tab Any
	)
	local keys=(
		'abcdefghijklmnopqrstuvwxyz'
		'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
		'`1234567890-=~!@#$%^&*()_+[]{}\|;:,./<>?"'\'
		"${names[*]} "
	)
	local Ckeys=("${keys[@]}")
	local Skeys=("${keys[@]}")
	local Mkeys=("${keys[@]}")

	local line
	for line in "${info[@]}"
	do
		if [[ "${line}" =~ ^'bind-key'[[:blank:]]*[-r]*[[:blank:]]*'-T'[[:blank:]]*"${table}"[[:blank:]]*([^[:blank:]]*) ]]
		then
			local key="${BASH_REMATCH[1]}"
			local arrname=keys
			if [[ "${key}" = @(C-*|S-*|M-*) ]]; then
				arrname="${key:0:1}keys"
				key="${key:2}"
			fi
			local -n arr="${arrname}"
			[[ "${key}" = \\? ]] && key="${key:1}"
			case "${key}" in
				[a-z]) arr[0]="${arr[0]/"${key}"/}" ;;
				[A-Z]) arr[1]="${arr[1]/"${key}"/}" ;;
				*)
					if ((${#key} > 1))
					then
						arr[3]="${arr[3]/"${key} "/}"
					else
						arr[2]="${arr[2]/"${key}"/}"
					fi
			esac
		fi
	done
	echo "${table}"
	for pre in '' C- S- M-
	do
		printf '\t%s\n' "${pre:-raw}"
		local -n arr="${pre::1}keys"
		printf '\t\t%s\n' "${arr[@]::${#arr[@]}-1}"
		printf '\t\t%s\t%s\t%s\t%s\n' ${arr[3]}
	done
}

tmux_freekeys() {
	local target_tables=()
	local listit=
	while (("${#}"))
	do
		case "${1}" in
			-h|--help)
				local msg="${BASH_SOURCE[0]} [-h] [-l] [tablename ...]
				-h|--help
				    display this help message
				-l|--list-tables
				    just list existing tables and exit.
				"
				echo "${msg//$'\t'}"
				return
				;;
			-l|--list-tables)
				listit=1
				;;
			*)
				target_tables+=("${1}")
		esac
		shift
	done
	((listit)) && target_tables=()
	local lines
	if ((${#target_tables[@]} == 1))
	then
		readarray -t lines < <(tmux list-keys -T "${target_tables[0]}")
	else
		readarray -t lines < <(tmux list-keys)
	fi
	if ((listit)); then
		extract_tables lines target_tables
		printf '%s\n' "${target_tables[@]}"
		return
	fi
	if ((!${#target_tables[@]}))
	then
		extract_tables lines target_tables
	fi

	local table
	for table in "${target_tables[@]}"
	do
		check_table lines "${table}"
	done
}

tmux_freekeys "${@}"
