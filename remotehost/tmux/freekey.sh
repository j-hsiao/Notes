#!/bin/bash

# Check for free keys without any bindings.
# NOTE: if tmux is started this is faster
# Otheriwse, tmux needs to parse the configs
# between each invocation.

_check() # <chars> [prefix]
{
	# Check each key if binding exists.
	for ((i=0; i<${#1}; ++i))
	do
		if ! tmux list-keys -T"${table}" "${2}${1:i:1}" &>/dev/null
		then
			printf "${1:i:1}"
		fi
	done
	echo
}

check() {
	table=prefix
	while (("${#}"))
	do
		case "${1}" in
			-T)
				shift
				table="${1}"
				;;
			-T*)
				table="${1:1}"
				;;
			*)
				echo "Unrecognized argument: ${1}"
				return 1
		esac
		shift
	done

	alpha=abcdefghijklmnopqrstuvwxyz
	printf 'Unused lower : '
	_check "${alpha}"
	printf 'Unused C-lower : '
	_check "${alpha}" C-

	printf 'Unused upper : '
	_check "${alpha^^}"

	printf 'Unused digit : '
	_check 01234567890

	printf 'Unused symbol: '
	_check '`~!@#$%^&*()-_=+[]{}\|;:"'"'"',<.>/?'

	echo 'Unused named keys:'
	for name in Up Down Left Right BSpace BTab DC End Enter Escape F{1..12} Home \
		IC NPage PPage Space Tab Any
	do
		if ! tmux list-keys -T"${table}" "${name}" &>/dev/null
		then
			echo "  ${name}"
		fi
	done
}

check "${@}"
