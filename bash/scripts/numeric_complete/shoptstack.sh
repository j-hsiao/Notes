#!/bin/bash

_SS_STATE=
_SS_push() # [(-|+)setting_name] ...
{
	# Set shopt options and push onto stack.
	# Calling _SS_pop() will pop the corresponding options.
	# NOTE: implemented via string manipulation.  The stack
	# should generally not be too deep anyways so it should be fine.
	local choice name add restore=: turnon=() turnoff=()
	for choice in "${@}"
	do
		add="${choice:0:1}"
		case "${add}" in
			-)
				name="${choice:1}"
				;;
			+)
				name="${choice:1}"
				;;
			*)
				add='+'
				name="${choice}"
				;;
		esac
		if [[ "${BASHOPTS}" =~ ^.*"${name}".*$ ]]
		then
			if [[ "${add}" = '-' ]]
			then
				turnoff+=("${name}");
				restore="${name} ${restore}"
			fi
		else
			if [[ "${add}" != '-' ]]
			then
				turnon+=("${name}")
				restore="${restore} ${name}"
			fi
		fi
	done
	if ((${#turnon[@]})); then shopt -s "${turnon[@]}"; fi
	if ((${#turnoff[@]})); then shopt -u "${turnoff[@]}"; fi
	_SS_STATE+=";${restore}"
}

_SS_pop()
{
	# Pop some settings off of the shopt stack.
	local restore="${_SS_STATE##*;}"
	if [[ "${restore:0:1}" != ':' ]]; then shopt -s ${restore%%:*}; fi
	if [[ "${restore:${#restore}-1}" != ':' ]]; then shopt -u ${restore##*:}; fi
	_SS_STATE="${_SS_STATE%;*}"
}
