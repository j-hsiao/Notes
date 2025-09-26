#!/bin/bash

SHOPTSTACK_STATE=
ss_push() # [(-|+)setting_name] ...
{
	# Set shopt options and push onto stack.
	# Calling ss_pop() will pop the corresponding options.
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
	SHOPTSTACK_STATE+=";${restore}"
}

ss_pop()
{
	# Pop some settings off of the shopt stack.
	local restore="${SHOPTSTACK_STATE##*;}"
	if [[ "${restore:0:1}" != ':' ]]; then shopt -s ${restore%%:*}; fi
	if [[ "${restore: -1}" != ':' ]]; then shopt -u ${restore##*:}; fi
	SHOPTSTACK_STATE="${SHOPTSTACK_STATE%;*}"
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo 'Testing shoptstack.'
	testcases=( \
		"$(shopt -p nullglob extglob globstar dotglob | cut -f2 -d' ')"
		'nullglob extglob globstar dotglob:'$'-s\n-s\n-s\n-s' \
		'-nullglob:'$'-u\n-s\n-s\n-s' \
		'globstar +dotglob:'$'-u\n-s\n-s\n-s' \
		'-nullglob +extglob +globstar:'$'-u\n-s\n-s\n-s' \
		'-nullglob -extglob -globstar -dotglob:'$'-u\n-u\n-u\n-u' \
	)

	echo 'Pushing shopt.'
	for testcase in "${testcases[@]:1}"
	do
		ss_push ${testcase%:*}
		[[ $(shopt -p nullglob extglob globstar dotglob | cut -f2 -d' ') = ${testcase##*:} ]] && echo pass || echo failed
	done

	echo 'Popping shopt.'
	idx=$((${#testcases[@]} - 1))
	while ((idx > 0))
	do
		ss_pop
		[[ $(shopt -p nullglob extglob globstar dotglob | cut -f2 -d' ') = ${testcases[--idx]##*:} ]] && echo pass || echo failed
	done

fi
