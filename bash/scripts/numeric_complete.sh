#!/bin/bash

# ------------------------------
# Numeric tab completion.
# ------------------------------
# When there is only 1 choice, it will be filled in as normal.  If there
# are multiple choices, then less will be used to display all the
# choices with a number.  Activating tab completion again after
# appending a number will choose that choice.  Modifying the current
# completion word will cause dir searching again which may be slow for
# network drives.  An initial tab completion will cache the choices.
# Making a choice will clear the cache.
# ------------------------------
# Relevant variables:
# ------------------------------
# 	NUMERIC_COMPLETE_CACHE_CHOICES
# 		If 0, then caching will only be done for the purposes of making
# 		a choice.  If no choice is made, then the directories will be
# 		searched again for completion choices.  Otherwise, if 1, the
# 		choices cache will remain and will be used for choices and
# 		completion until a different directory is searched.
# 	NUMERIC_COMPLETE_ALIAS
# 		The alias to use for activating numeric completion.  This will
# 		be aliased to the empty string.  Defaults to 'n'.
# 		example:
# 			NUMERIC_COMPLETE_ALIAS=myalias
# 			source numeric_complete.sh
# 			myalias ls [tab]  -> numeric completion
# 	NUMERIC_COMPLETE_DEFAULT
# 		A readline key sequence, defaulting to "\C-j\C-k".
# 		(control-j control-k) If set, numeric_complete will be
# 		registered as a default completion and
# 		"${NUMERIC_COMPLETE_DEFAULT}" will be bound to complete.
# 		"${COMP_KEY}" will be used to determine whether the default
# 		completion or numeric completion should be used.  Because
# 		COMP_KEY only looks at the last key used,
# 		NUMERIC_COMPLETE_DEFAULT should not end with '\t' or '\C-i'.
# 		The standard tab completion from the tab key will do normal
# 		completion (compgen -o default), and the key sequence specified
# 		by NUMERIC_COMPLETE_DEFAULT will do numeric complete.
# 	NUMERIC_COMPLETE_PAGER=()
# 		This contains the paging command for displaying potential
# 		choices.  By default, it is empty (print to terminal).  Set it
# 		to a command of your choice or call numeric_complete_set_pager
# 		to set it.  numeric_complete_set_pager will default to less if
# 		available. Fall back to just printing to the terminal.
# 		more doesn't restore the terminal screen so it will screw up the
# 		prompt if piped to it. But if have to restore the prompt anyways
# 		might as well just print to terminal.  more would only allow
# 		quitting before reaching the end.  Plus, the columns and
# 		alignment seemed to be off when testing, so just don't use more.
# 	numeric_complete_choices
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
# 	As usual, completion should properly quote any weird names.


# ------------------------------
# ?possible improvements?
# ------------------------------
# cache dir search, even if modified, if the dir is the same, then no
# need to read dir again, might speed this up...
# otherwise, could try saving a cache/use a LRU cache or something
# then less need to search directories... but if dir is updated
# (rm/new file), would need to re-search anyways... maybe not necessary.
#
# ------------------------------
# Observations
# ------------------------------
# 1. ls vs compgen
# 	1. local drive
# 		compgen is the fastest option hands down.  However, it does not
# 		have colors.
# 	2. network drive
# 		compgen -f and raw ls have similar performances.  However, to
# 		get color/type ls -Ap will run slower.  compgen -df is the slowest
# 		and has no colors.
#
# 		choose ls to search for completion options.

NUMERIC_COMPLETE_PAGER=()
NUMERIC_COMPLETE_CACHE_CHOICES=${NUMERIC_COMPLETE_CACHE_CHOICES-0}

numeric_complete_choices=()

# I've found that process substitution seems to take
# a significant amount of time, so just save these values
# somewhere...
#
NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT="$(bind -v 2>&1)"
NUMERIC_COMPLETE_IGNORE_CASE="${NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT#*completion-ignore-case }"
NUMERIC_COMPLETE_IGNORE_CASE="${NUMERIC_COMPLETE_IGNORE_CASE:0:2}"

NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT="${NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT#*show-mode-in-prompt }"
NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT="${NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT:0:2}"




#Automatically set the pager for displaying choices.
numeric_complete_set_pager()
{
	NUMERIC_COMPLETE_PAGER=()
	local lessname lessver lessother
	if read lessname lessver lessother < <(less --version 2>&1)
	then
		if [[ "${lessver}" =~ ^[0-9]+$ ]]
		then
			if [[ "${lessver}" -ge 600 ]]
			then
				NUMERIC_COMPLETE_PAGER=(less -R -~ --header 2)
			else
				NUMERIC_COMPLETE_PAGER=(less -R -~ +1)
			fi
		fi
	fi
}


numeric_complete_set_extglob() {
	declare -n Nreset_extglob="${1}"
	if [[ "${BASHOPTS}" =~ ^.*extglob.*$ ]]
	then
		Nreset_extglob=()
	else
		shopt -s extglob
		Nreset_extglob=(shopt -u extglob)
	fi
}

# numeric_complete_parse_word completion_word
#
# Parse the completion word into dirname and base.
# If no dirname, then it will be empty.
numeric_complete_parse_word() {
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
	if [[ "${dname:0:1}" != '/' ]]
	then
		dname="${PWD}/${dname}"
	fi
}

# numeric_complete_max num_array_name start stop output
#
# Calculate the maximum of an array of numeric values >= 0 of the
# range from start to stop.
numeric_complete_max()
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

# numeric_complete_calc_shape strwidths start stop rowout colout
# Calculate the rows and cols to display.
# strwidths: array of lengths of str
# start/stop: range in strwidths to display (start included, stop excluded)
# rowout/colout: output variables to store row/col values
# Expect termwidth to be defined to columns of terminal
numeric_complete_calc_shape()
{
	declare -n Narr="${1}" Nrowout="${4}" Ncolout="${5}" Ncolwidths="${6}" Nprewidth="${7}"
	local nchoices="$((${3} - ${2}))" maxwidth
	numeric_complete_max Narr "${2}" "${3}" maxwidth
	Nprewidth=$(("${#nchoices}" + 1))
	local ncols=$((termwidth / (maxwidth+Nprewidth)))
	if [[ "${ncols}" -lt 1 || $(("${ncols}"-1)) -gt $((termwidth % (maxwidth+Nprewidth))) ]]
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

	while [[ "${ncols}" -lt "${nchoices}" && "$(( ((Nprewidth + 1) * ncols) - 1))" -le $((termwidth)) ]]
	do
		local ncols=$((ncols+1))
		nrows="$(((nchoices / ncols) + ((nchoices % ncols) > 0)))"
		if [[ $(((nrows * ncols) - nchoices)) -lt nrows ]]
		then
			local netwidth=0 start=${2} curwidth tcolwidths=()
			local textspace=$((termwidth - ((ncols*(Nprewidth+1)) - 1)))
			while [[ "${start}" -lt "${3}" && "${netwidth}" -le "${textspace}" ]]
			do
				numeric_complete_max Narr "${start}" "$(( (start+nrows) < "${3}" ? (start+nrows) : "${3}" ))" curwidth
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


# Mimic prompt text and commandline (needs bash >= 4.4)
# Expect termwidth to be defined to columns of terminal
numeric_complete_mimic_prompt()
{
	if [[ "${NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT}" == 'on' ]]
	then
		local modeprompt=' '
	else
		local modeprompt=
	fi
	local replicate="${modeprompt}${PS1@P}${COMP_LINE}" nlines=0
	while [[ -n "${replicate}" ]]
	do
		local seg="${replicate%%$'\n'*}"
		if [[ "${seg}" = "${replicate}" ]]
		then
			replicate=
		else
			replicate="${replicate#*$'\n'}"
		fi
		nlines="$((nlines + ${#seg}/termwidth + (${#seg}%termwidth > 0)))"
	done
	local restore=$'\e['"${nlines}"'A'
	while [[ "${nlines}" -gt 0 ]]
	do
		printf '\n'
		nlines=$((nlines-1))
	done
	printf '%s' \
		"${restore}" \
		"${PS1@P}" \
		"${modeprompt}" \
		"${COMP_LINE:0:${COMP_POINT}}" \
		$'\e[s' \
		"${COMP_LINE:${COMP_POINT}}" \
		$'\e[u'
}

# Some column command might not handle proper alignment with colors
numeric_complete_display_choices()
{
	local reset_shopt
	numeric_complete_set_extglob reset_shopt
	# TODO: calc unicode strwidths
	local strwidths=("${numeric_complete_choices[@]//$'\e'\[*([0-9;])[a-zA-Z]/}") idx=2
	"${reset_shopt[@]}"
	while [[ "${idx}" -lt "${#strwidths[@]}" ]]
	do
		strwidths[idx]="${#strwidths[idx]}"
		idx=$((idx+1))
	done
	local rows cols widths prewidth termwidth
	if [[ "${BASHOPTS}" =~ ^(.+:)?checkwinsize(:.+)?$ || "${-}" =~ ^.*i.*$ ]]
	then
		termwidth="${COLUMNS}"
		if [[ -z "${termwidth}" ]]
		then
			termwidth=$(tput cols)
			COLUMNS="${termwidth}"
		fi
	else
		# If using tab completion, then kinda expect it to be
		# interactive.  Man says if interactive, then COLUMNS will be
		# set appropriately so ideally this should never happen
		# anyways.
		termwidth=$(tput cols)
	fi
	numeric_complete_calc_shape strwidths 2 "${#strwidths[@]}" rows cols widths prewidth
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

	if [[ "${#NUMERIC_COMPLETE_PAGER[@]}" -gt 0 ]]
	then
		numeric_complete_print_table 1 | "${NUMERIC_COMPLETE_PAGER[@]}"
	else
		printf '\n'
		numeric_complete_print_table
		local multitab
		printf -v multitab '%d' "'?"
		if [[ "${COMP_TYPE}" -ne "${multitab}" ]]
		then
			numeric_complete_mimic_prompt
		fi
	fi
}

# TODO print non-ascii utf-8 characters
# incorrect size -> busted columns
#
#https://stackoverflow.com/questions/36380867/how-to-get-the-number-of-columns-occupied-by-a-character-in-terminal
#widths = [
#     (126, 1), (159, 0), (687, 1), (710, 0), (711, 1),
#     (727, 0), (733, 1), (879, 0), (1154, 1), (1161, 0),
#     (4347, 1), (4447, 2), (7467, 1), (7521, 0), (8369, 1),
#     (8426, 0), (9000, 1), (9002, 2), (11021, 1), (12350, 2),
#     (12351, 1), (12438, 2), (12442, 0), (19893, 2), (19967, 1),
#     (55203, 2), (63743, 1), (64106, 2), (65039, 1), (65059, 0),
#     (65131, 2), (65279, 1), (65376, 2), (65500, 1), (65510, 2),
#     (120831, 1), (262141, 2), (1114109, 1),
# ]

# # ACCESSOR FUNCTIONS

# def get_width( o ):
#     """Return the screen column width for unicode ordinal o."""
#     global widths
#     if o == 0xe or o == 0xf:
#         return 0
#     for num, wid in widths:
#         if o <= num:
#             return wid
#     return 1
numeric_complete_print_table()
{
	local currow=0
	while [[ ${currow} -lt "${rows}" ]]
	do
		if [[ "${currow}" -eq 0 ]]
		then
			printf '%sEnter the number choice then press tab to select.\n\n' \
				"${1:+Press \"q\" to return.  }"
		fi
		local curcol=0
		while [[ ${curcol} -lt ${cols} ]]
		do
			idx=$(( (curcol*rows) + currow ))
			if [[ "$((idx+2))" -lt "${#numeric_complete_choices[@]}" ]]
			then
				# printf does not parse ansi so must calculate padding
				# manually  Column is thrown off by ansi so wrong
				# widths.
				printf '%'"${prepad[curcol]}"'s%'"${numwidth}"'d %s%'"$(("${widths[curcol]}" - "${strwidths[idx+2]}"))"'s' \
					'' "$((idx+1))" "${numeric_complete_choices[idx+2]}" ''
			fi
			curcol=$((curcol+1))
		done
		printf '\n'
		currow=$((currow+1))
	done
}

numeric_complete_search_ls() {
	# ls with a glob will expand the glob searching the dir once
	# and then ls which goes through the dir again.  To only do
	# one pass (?faster?) for network drive, need to list the
	# containing directory and then manually filter.

	numeric_complete_choices=("${1}" "${dname}")
	local lsargs=()
	if [[ -n "${dname}" ]]
	then
		lsargs=("${dname}")
	fi

	readarray -O 2 -t numeric_complete_choices < <(ls -Ap --color=always "${lsargs[@]}" 2>/dev/null)

	local iter=2 setting=2 size="${#numeric_complete_choices[@]}" reset_shopt
	numeric_complete_set_extglob reset_shopt
	local raw=("${numeric_complete_choices[@]//$'\e'\[*([0-9;])[a-zA-Z]}")
	"${reset_shopt[@]}"
	# check if case insensitive?
	if [[ "${NUMERIC_COMPLETE_IGNORE_CASE}" = 'on' ]]
	then
		raw=("${raw[@],,}")
		base="${base,,}"
	fi
	while [[ "${iter}" -lt "${size}" ]]
	do
		if [[ "${raw[iter]}" =~ ^"${base}".* ]]
		then
			numeric_complete_choices[setting]="${numeric_complete_choices[iter]}"
			setting=$[setting+1]
		fi
		iter=$[iter+1]
	done
	while [[ "${setting}" -lt "${size}" ]]
	do
		unset 'numeric_complete_choices[setting]'
		setting=$[setting+1]
	done
}


# Set COMPREPLY array.
# numeric_complete_set_COMPREPLY [choice (int)] [curword]
numeric_complete_set_COMPREPLY()
{
	local reset_shopt
	numeric_complete_set_extglob reset_shopt
	local basechoice="${numeric_complete_choices[${1}]//$'\e'\[*([0-9;])[a-zA-Z]}"
	"${reset_shopt[@]}"

	if [[ "${2:${#2}-1}" = '/' ]]
	then
		COMPREPLY=("${2}${basechoice}")
	else
		COMPREPLY=("${2%/*}")
		if [[ "${COMPREPLY[0]}" = "${2}" ]]
		then
			COMPREPLY=("${basechoice}")
		else
			COMPREPLY=("${COMPREPLY[0]}/${basechoice}")
		fi
	fi
	if [[ "${COMPREPLY[0]:${#COMPREPLY[0]}-1}" != '/' ]]
	then
		COMPREPLY[0]="${COMPREPLY[0]} "
	fi
}

numeric_complete() {
	local reset_shopt
	numeric_complete_set_extglob reset_shopt
	local target="${2/#~*(\/)/${HOME}/}"
	"${reset_shopt[@]}"

	printf '*%s' $'\e[D'
	local extra="${target#${numeric_complete_choices[0]}}"

	if [[ ("${extra}" != "${target}" || "${numeric_complete_choices[0]}" = '' ) && "${extra}" =~ ^[0-9]+$ && "${extra}" -lt "${#numeric_complete_choices[@]}" ]]
	then
		numeric_complete_set_COMPREPLY $((extra+1)) "${2}"
		if [[ "${NUMERIC_COMPLETE_CACHE_CHOICES}" -eq 0 ]]
		then
			numeric_complete_choices=()
		fi
	else
		if [[ "${COMP_KEY}" -ne 9 || ${NUMERIC_COMPLETE_ALIAS:-n} = "${1}" ]]
		then
			local dname base
			numeric_complete_parse_word "${2}"
			if [[ "${NUMERIC_COMPLETE_CACHE_CHOICES}" -eq 0 || "${dname}" != "${numeric_complete_choices[1]}" ]]
			then
				numeric_complete_search_ls "${target}"
			fi
			if [[ "${#numeric_complete_choices[@]}" -eq 3 ]]
			then
				numeric_complete_set_COMPREPLY 2 "${2}"
				if [[ "${NUMERIC_COMPLETE_CACHE_CHOICES}" -eq 0 ]]
				then
					numeric_complete_choices=()
				fi
			else
				if [[ "${#numeric_complete_choices[@]}" -gt 3 ]]
				then
					numeric_complete_display_choices
				fi
				# if COMP_TYPE is multitab, then all the COMPREPLY choices
				# will be printed out.  Want to avoid this, so empty string
				# as only choice + up cursor to "undo" the extra printed lines.
				# -o nospace + empty string for some reason:
				# 1. does not delete current word ?is this a bug?
				#    if Non-empty, even if shorter than "${2}", it will replace
				#    but empty string does not.
				# 2. does not modify the current line.
				# if without -o nospace, then a space will be added at current
				# position on command line = messed up.
				local multitab
				printf -v multitab '%d' "'?"
				if [[ "${COMP_TYPE}" = "${multitab}" ]]
				then
					# cygwin seems to print extra lines
					# so need to move up more
					if [[ "${OS}" = *'Windows'* ]]
					then
						printf $'\e[2A'
					else
						printf $'\e[A'
					fi
				fi
				COMPREPLY=('')
			fi
		fi
	fi
	local restore=${COMP_LINE:${COMP_POINT}:1}
	printf '%s\e[D' "${restore:- }"
}

alias ${NUMERIC_COMPLETE_ALIAS:-n}=''
complete -o default -o nospace -F numeric_complete ${NUMERIC_COMPLETE_ALIAS:-n}

if [[ -n "${NUMERIC_COMPLETE_DEFAULT-\\C-j\\C-k}" ]]
then
	complete -D -o default -o nospace -F numeric_complete
	bind \""${NUMERIC_COMPLETE_DEFAULT-\\C-j\\C-k}"'":complete'
fi
