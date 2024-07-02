#!/bin/bash

# n is aliased to nothing
# NOTE: this is not suitable for menu completion
#   This is because "fake" completion choices are
#   chosen for displaying to the user.  menu completion
#   would try to use these fake completion choices which
#   would give the wrong result.
# Add n before any commands to use num completion.
# tab to activate completion.  Whenver completion is
# activated on an empty basename (ending with a /)
# list numbered options.
# End with the number to choose it
# eg.
# commandline:          tab result
# n cd /some/path/      list numbered choices
# n cd /some/path/5     choose the 5th choice
# n cd /some/path/p     normal completion anything starting with p

# cache results of listing choices.
# sometimes listing choices can be somewhat expensive so
# caching may help improve performance
numeric_completion_choices=()
alias n=''
function num_complete() {
	local target="${2}"
	if [[ "${target}" =~ ^[0-9]*$ ]]
	then
		target="./${target}"
	elif [[ "${target}" =~ ^'~/'.* || "${target}" = '~' || "${target}" =~ '~'[0-9]+ ]]
	then
		target="${target/#'~'/"${HOME}/"}"
	fi

	if [[ "${target}" =~ ^.*/[0-9]+$ && "${#numeric_completion_choices[@]}" -gt 0 && "${numeric_completion_choices[0]}${target##*/}" = "${PWD}${COMP_WORDS[*]}" ]]
	then
		COMPREPLY=("${target%/*}/${numeric_completion_choices[${target##*/}]}")
		return
	fi

	printf '*\b'
	if [[ "${target}" =~ ^.*/[0-9]*$ ]]
	then
		if [ "${COMP_WORDS[1]}" = cd ]
		then
			# special handling for cd: only dirnames
			readarray -t COMPREPLY < <(compgen -o dirnames "${target%/*}/")
			# compgen will give the entire path
			COMPREPLY=("${COMPREPLY[@]##*/}")
		else
			# ls only gives the individual file/dirname
			readarray -t COMPREPLY < <(ls -Ap "${target%/*}/")
		fi
		if [ -n "${target##*/}" ]
		then
			COMPREPLY=("${target%/*}/${COMPREPLY[${target##*/}-1]}")
			numeric_completion_choices=()
		else
			if [ -z "${NCOMPLETE_NO_CACHE}" ]
			then
				numeric_completion_choices=("${PWD}${COMP_WORDS[*]}" "${COMPREPLY[@]}")
			fi
			if [ "${#COMPREPLY[@]}" -gt 1 ]
			then
				# enumerate choices with 0-padded numbers(so properly sorted)
				while read target
				do
					COMPREPLY[$((10#${target}-1))]="${target} ${COMPREPLY[$((10#${target}-1))]}"
				done < <(seq -w "${#COMPREPLY[@]}")
			elif [ "${#COMPREPLY[@]}" -eq 1 ]
			then
				COMPREPLY=("${target%/*}/${COMPREPLY[0]}")
			fi
		fi
	else
		numeric_completion_choices=()
	fi
}
complete -o bashdefault -o default -o nospace -o filenames -F num_complete n
