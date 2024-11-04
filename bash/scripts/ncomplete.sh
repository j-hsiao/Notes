#!/bin/bash

# ------------------------------
# Numeric tab completion.
# ------------------------------
# When there is only 1 choice, it will be filled in as normal.  If there
# are multiple choices, then less will be used to display all the
# choices with a number.  Activating tab completion again after
# appending a number will choose that choice.  Modifying the current
# completion word will cause dir searching again which may be slow for
# network drives.  However, pressing tab without modification will use
# cached results.
# ------------------------------
# Relevant variables:
# ------------------------------
# 	NUMERIC_COMPLETE_DEFAULT
# 		If this is defined and non-empty, before the script is run, then
# 		numeric completion will be defined as the default.
# 		Otherwise, "n" will be aliased to the empty string.
# 			alias n=''
# 		To activate numeric completion, just prepend 'n ' to the
# 		command line.
# 		normal completion:
# 			ls asd[tab]
# 		numeric completion:
# 			n ls asd[tab]
# 	numeric_completion_choices
# 		This is an array that will cache the last directory search for
# 		matches.  This way, directories are only searched once.
# 		Making a numeric choice will just search the cached result. This
# 		should make numeric completion on network drives a bit faster
# 		rather than having to read the directory twice: once to display
# 		choices, and again to complete the choice.
# ------------------------------
# Examples:
# ------------------------------
# directory structure:
# 	current dir/
# 		dir1/
# 			f1
# 			f2
# 			dir2/
# 				f with space'and quote
# 				f2
# ------------------------------
# ex1:
# 	$ n ls d[tab]
# 	$ n ls dir1/
#
# 	There is only one choice so the d is expanded to "dir1/"
# ------------------------------
# ex2:
# 	$ n ls dir1/[tab]
# 		1 dir2/ 2 f1    3 f2
#
# 	There are 3 choices: f1, f2, and dir2/ which will be displayed
# 	by less.  Dirs will have a trailing "/" to differentiate them.
# ------------------------------
# ex3:
# 	$ n ls dir1/[tab]
# 		1 dir2/ 2 f1    3 f2
# 	$ n ls dir1/3[tab]
# 	$ n ls dir1/f2
#
# 	After listing the choices, 3 is chosen followed by a tab.  This
# 	reactivates tab completion to choose the 3rd choice.
# ------------------------------
# ex 4:
# 	$ n ls dir1/3[tab]
# 	$ n ls dir1/3
#
# 	Choices were not listed so this will attempt to perform completion
# 	on directory entries that start with "3".  There are no such choises
# 	so nothing happens.
# ------------------------------
# ex 5:
# 	$ n ls dir1/dir2/[tab]
# 		1 f with space'and quote        2 f2
# 	$ n ls dir1/dir2/1[tab]
# 	$ n ls dir1/dir2/f\ with\ space\'and\ quote
#
#	As usual, completion should properly quote any weird names.


# ------------------------------
# ?possible improvements?
# ------------------------------
# cache dir search, even if modified, if the dir is the same, then no
# need to read dir again, might speed this up...
# otherwise, could try saving a cache/use a LRU cache or something
# then less need to search directories... but if dir is updated
# (rm/new file), would need to re-search anyways... maybe not necessary.

numeric_completion_choices=()

numeric_set_extglob() {
	declare -n Nreset_extglob="${1}"
	if [[ "${BASHOPTS}" =~ ^.*extglob.*$ ]]
	then
		Nreset_extglob=()
	else
		shopt -s extglob
		Nreset_extglob=(shopt -u extglob)
	fi
}

# numeric_parse_word completion_word
#
# Parse the completion word into dirname and base.
# If no dirname, then it will be empty.
numeric_parse_word() {
	if [[ "${1:${#1}-1}" = '/' ]]
	then
		dname="${1}"
		base=''
	else
		dname="${1%/*}"
		base="${1##*/}"
		if [[ "${dname}" = "${1}" ]]
		then
			dname=''
		else
			dname="${dname}/"
		fi
	fi
}

# numeric_max num_array_name start stop output
#
# Calculate the maximum of an array of numeric values >= 0 of the
# range from start to stop.
numeric_max()
{
	declare -n output="${4}"
	declare -n ref_array="${1}"
	local idx="${2}"
	output=0
	while [[ "${idx}" -lt "${3}" ]]
	do
		if [[ "${ref_array[idx]}" -gt "${output}" ]]
		then
			output="${ref_array[idx]}"
		fi
		idx=$((idx+1))
	done
}

# numeric_calc_shape strwidths start stop rowout colout
# Calculate the rows and cols to display.
# strwidths: array of lengths of str
# start/stop: range in strwidths to display (start included, stop excluded)
# rowout/colout: output variables to store row/col values
numeric_calc_shape()
{
	declare -n Narr="${1}" Nrowout="${4}" Ncolout="${5}" Ncolwidths="${6}" Nprewidth="${7}" Ntermwidth="${8}"
	local nchoices="$((${3} - ${2}))" maxwidth
	numeric_max Narr "${2}" "${3}" maxwidth
	Ntermwidth=$(tput cols)
	Nprewidth=$(("${#nchoices}" + 1))
	local ncols=$((Ntermwidth / (maxwidth+Nprewidth)))
	if [[ "${ncols}" -lt 1 || $(("${ncols}"-1)) -gt $((Ntermwidth % (maxwidth+Nprewidth))) ]]
	then
		if [[ "${ncols}" -le 1 ]]
		then
			Nrowout="${nchoices}"
			Ncolout=1
			return
		else
			ncols=$((ncols-1))
		fi
	fi
	Nrowout="$(((nchoices / ncols) + ((nchoices % ncols) > 0)))"
	Ncolout="${ncols}"
	local idx=0
	Ncolwidths=()
	while [[ "${idx}" -lt "${ncols}" ]]
	do
		Ncolwidths+=("${maxwidth}")
		idx=$((idx+1))
	done

	while [[ "${ncols}" -lt "${nchoices}" && "$(( ((Nprewidth + 1) * ncols) - 1))" -le $((Ntermwidth)) ]]
	do
		local ncols=$((ncols+1))
		nrows="$(((nchoices / ncols) + ((nchoices % ncols) > 0)))"
		if [[ $(((nrows * ncols) - nchoices)) -lt nrows ]]
		then
			local netwidth=0 start=${2} curwidth tcolwidths=()
			local textspace=$((Ntermwidth - ((ncols*(Nprewidth+1)) - 1)))
			while [[ "${start}" -lt "${3}" && "${netwidth}" -le "${textspace}" ]]
			do
				numeric_max Narr "${start}" "$(( (start+nrows) < "${3}" ? (start+nrows) : "${3}" ))" curwidth
				tcolwidths+=("${curwidth}")
				netwidth=$((netwidth + curwidth))
				start=$((start + nrows))
			done
			if [[ "${netwidth}" -le ${textspace} && "${start}" -ge "${3}" ]]
			then
				Nrowout="${nrows}"
				Ncolout="${ncols}"
				Ncolwidths=("${tcolwidths[@]}")
			fi
		fi
	done
}

# Some column command might not handle proper alignment with colors
numeric_display_choices()
{
	local reset_shopt
	numeric_set_extglob reset_shopt
	local strwidths=("${numeric_completion_choices[@]//$'\e'\[*([0-9;])[a-zA-Z]/}") idx=2
	"${reset_shopt[@]}"
	while [[ "${idx}" -lt "${#strwidths[@]}" ]]
	do
		strwidths[idx]="${#strwidths[idx]}"
		idx=$((idx+1))
	done
	local rows cols widths
	numeric_calc_shape strwidths 2 "${#strwidths[@]}" rows cols widths prewidth termwidth
	local numwidth="$((prewidth-1))" prepad=(0) padspace=$((termwidth - (cols*prewidth)))
	for idx in "${widths[@]}"
	do
		padspace=$((padspace - idx))
	done

	idx=1
	while [[ "${idx}" -lt "${cols}" ]]
	do
		prepad+=("$(((idx * padspace) / (cols-1)))")
		idx=$((idx+1))
	done
	idx=$((cols-1))
	while [[ "${idx}" -gt 0 ]]
	do
		prepad[idx]="$((prepad[idx] - ${prepad[idx-1]}))"
		idx=$((idx-1))
	done

	local currow=0
	while [[ ${currow} -lt "${rows}" ]]
	do
		local curcol=0
		while [[ ${curcol} -lt ${cols} ]]
		do
			idx=$(( (curcol*rows) + currow ))
			if [[ "$((idx+2))" -lt "${#numeric_completion_choices[@]}" ]]
			then
				# printf does not parse ansi so must calculate padding
				# manually
				printf '%'"${prepad[curcol]}"'s%'"${numwidth}"'d %s%'"$(("${widths[curcol]}" - "${strwidths[idx+2]}"))"'s' \
					'' "$((idx+1))" "${numeric_completion_choices[idx+2]}" ''
			fi
			curcol=$((curcol+1))
		done
		printf '\n'
		currow=$((currow+1))
	done | less -R
}

numeric_search_ls() {
	# ls with a glob will expand the glob searching the dir once
	# and then ls which goes through the dir again.  To only do
	# one pass (?faster?) for network drive, need to list the
	# containing directory and then manually filter.
	local dname base
	numeric_parse_word "${1}"

	numeric_completion_choices=("${1}" "${dname}")
	local lsargs=()
	if [[ -n "${dname}" ]]
	then
		lsargs=("${dname}")
	fi

	readarray -O 2 -t numeric_completion_choices < <(ls -Ap --color=always "${lsargs[@]}" 2>/dev/null)

	local iter=2 setting=2 size="${#numeric_completion_choices[@]}" reset_shopt
	numeric_set_extglob reset_shopt
	local raw=("${numeric_completion_choices[@]//$'\e'\[*([0-9;])[a-zA-Z]}")
	"${reset_shopt[@]}"
	# check if case insensitive?
	local caseinsensitive="$(bind -v 2>&1)"
	caseinsensitive="${caseinsensitive#*completion-ignore-case }"
	if [[ "${caseinsensitive::2}" = 'on' ]]
	then
		raw=("${raw[@],,}")
		base="${base,,}"
	fi
	while [[ "${iter}" -lt "${size}" ]]
	do
		if [[ "${raw[iter]}" =~ ^"${base}".* ]]
		then
			numeric_completion_choices[setting]="${numeric_completion_choices[iter]}"
			setting=$[setting+1]
		fi
		iter=$[iter+1]
	done
	while [[ "${setting}" -lt "${size}" ]]
	do
		unset 'numeric_completion_choices[setting]'
		setting=$[setting+1]
	done
}


numeric_set_COMPREPLY()
{
	local reset_shopt
	numeric_set_extglob reset_shopt
	COMPREPLY=("${numeric_completion_choices[1]}${numeric_completion_choices[${1}]//$'\e'\[*([0-9;])[a-zA-Z]}")
	"${reset_shopt[@]}"
}

numeric_complete() {
	printf '%s*%s' $'\e[s' $'\e[u'
	local extra="${2#${numeric_completion_choices[0]}}"

	if [[ ("${extra}" != "${2}" || "${numeric_completion_choices[0]}" = '' ) && "${extra}" =~ ^[0-9]+$ && "${extra}" -lt "${#numeric_completion_choices[@]}" ]]
	then
		numeric_set_COMPREPLY $((extra+1))
		numeric_completion_choices=()
	else
		# if [[ "${#numeric_completion_choices[@]}" -eq 0 ||  "${2}" != "${numeric_completion_choices[0]}" ]]
		# then
		# 	numeric_search_ls "${2}"
		# fi

		# if rm or dir changes etc, then would need to look again...
		# so maybe don't save the cache unless choosing...
		numeric_search_ls "${2}"
		if [[ "${#numeric_completion_choices[@]}" -eq 3 ]]
		then
			numeric_set_COMPREPLY 2
			numeric_completion_choices=()
		else
			if [[ "${#numeric_completion_choices[@]}" -gt 3 ]]
			then
				numeric_display_choices
				# printf '%s\n' "${numeric_completion_choices[@]:2}" | cat -n | tr '\t' ' ' | column | less
			fi
			numeric_completion_choices+=("${tmp[@]}")
			COMPREPLY=()
		fi
	fi
	printf '%s %s' $'\e[s' $'\e[u'
}
if [[ "${NUMERIC_COMPLETE_DEFAULT}" ]]
then
	complete -D -o filenames -F numeric_complete
else
	alias n=''
	complete -o filenames -F numeric_complete n
fi
