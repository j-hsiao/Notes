#!/bin/bash


MIN_CMD_COMPLETION_LENGTH=3

_mincmd_complete()
{
	# bash attempts completion treating the text as a variable
	# (if the text begins with a $), username (if the text begins with
	# ~) hostname (if the text begins with @), or command (including
	# aliases and functions) in turn. If none of these produces a match,
	# filename completion is attempted
	if [[ "${#2}" -eq 0 ]]
	then
		# Not sure why fully empty is even slower than having a single
		# prefix char or anything... doesn't it still have to search all
		# the same paths? Maybe because the list becomes so large, it
		# ends up being slow due to memory issues? Constant realloc?
		COMPREPLY=()
	elif [[ "${2}" =~ ^\$.* ]]
	then
		readarray -t COMPREPLY < <(compgen -v "${2:1}")
		COMPREPLY=("${COMPREPLY[@]/#/\$}")
	elif [[ "${2}" =~ .*/.* ]]
	then
		# partial path, greatly narrows search space, just complete immediately.
		readarray -t COMPREPLY < <(compgen -c "${2}")
	elif [[ "${#2}" -lt "${MIN_CMD_COMPLETION_LENGTH}" && "${COMP_TYPE}" -ne 63 ]]
	then
		printf '\nWarning: short command, ignoring initial completion!\n' >&2
		prompt="${PS1@P}"
		printf '%s%s\r%s%s' "${prompt}" "${COMP_LINE}" "${prompt##*$'\n'}" "${COMP_LINE:0:COMP_POINT}"

		# nospace + single option so the line
		# does not change, must be non-empty or bashdefault
		# will be triggered.
		# compgen does not have a -I option
		COMPREPLY=()
	else
		# -c seems to include both -A function and -A alias (-a)
		# so just do -c only, reduce duplicates
		readarray -t COMPREPLY < <(compgen -c "${2}")
		#COMPREPLY=("${COMPREPLY[@]/%/ }")
	fi
}

# Strange, whitespace followed by tab to trigger completion
# triggers neither default (-D) norm empty (-E).  It would still
# hang though...  Calling complete with empty string also
# does not get triggered.
# also, default completion (-D) seems to never be triggered at all

complete -E
complete -I -F _mincmd_complete -o filenames

# Alternative to complete for empty case.
# shopt -s no_empty_cmd_completion
