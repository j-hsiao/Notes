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
# Making a choice will clear the cache.  Public functions/variables
# will be prefixed with 'NUMERIC_COMPLETE_'.  Internal functions/variables
# will be prefixed with _NC_
# ------------------------------
# Relevant variables:
# ------------------------------
# 	Keys:
# 		These must be set prior to sourcing this script.  They will be
# 		used to call `bind` with the corresponding arguments to activate
# 		completion.  These variables are keys for bindings to numeric
# 		completion and should be a single character long.  If using vim,
# 		type control-v before hitting the key/key combo.  Alternatively,
# 		if the key code is already known, the bash syntax $'\xNN' where
# 		NN is the hex key code can also be used.  ($'\x0a' = a newline,
# 		same as $'\n')
#
# 		NUMERIC_COMPLETE_prefix (C-l)
# 			All numeric completion bindings start with this key.
# 		NUMERIC_COMPLETE_default (C-k)
# 			A key for default numeric completion.  The default will always
# 			read the corresponding directory for completion.
# 	Settings
# 		NUMERIC_COMPLETE_alias
# 			The alias to use for activating numeric completion.  This will
# 			be aliased to the empty string.  Defaults to 'n'.
# 			example:
# 				NUMERIC_COMPLETE_alias=myalias
# 				source numeric_complete.sh
# 				myalias ls [tab]  -> numeric completion
# 		NUMERIC_COMPLETE_pager=()
# 			This contains the paging command for displaying potential
# 			choices.  By default, it is empty (print to terminal).  Set it
# 			to a command of your choice or call numeric_complete_set_pager
# 			to set it.  numeric_complete_set_pager will default to less if
# 			available. Fall back to just printing to the terminal.
# 			more doesn't restore the terminal screen so it will screw up the
# 			prompt if piped to it. But if have to restore the prompt anyways
# 			might as well just print to terminal.  more would only allow
# 			quitting before reaching the end.  Plus, the columns and
# 			alignment seemed to be off when testing, so just don't use more.
# 	Data
# 		numeric_complete_choices
# 			This is an array that will cache the last directory search for
# 			matches.  This way, directories are only searched once.
# 			Making a numeric choice will just search the cached result. This
# 			should make numeric completion on network drives a bit faster
# 			rather than having to read the directory twice: once to display
# 			choices, and again to complete the choice.
# 	Readline Settings
#
# 		NUMERIC_COMPLETE_SHOW_MODE_IN_PROMPT
# 			on/of, This is parsed from the output of `bind -v`.
# 		NUMERIC_COMPLETE_IGNORE_CASE
# 			on/of, this is parsed from the output of `bind -v`.
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

# TODO:
# 1. Caching, separate reading directory from the completion choices.
# 2. Calculate lengths only once, reduce calc times etc?
# 3. Implement caching behavior:
#    If directory changed (numeric_complete_choices[1]), read new dir.
#    Otherwise, check if cur word prefix changed somehow.
#    If added to cur word, refine choices in numeric_complete_choices
#    If removed, refine from cached dir read.
#    If no change, no updates needed.
# 4. Use printf %q, quote the returned completion.


# ------------------------------
# variables
# ------------------------------
# ------------------------------
# keys
# ------------------------------
NUMERIC_COMPLETE_prefix="${NUMERIC_COMPLETE_prefix:-}"
NUMERIC_COMPLETE_default="${NUMERIC_COMPLETE_default-}"

# ------------------------------
# settings
# ------------------------------
# Some commands already have some complete function defined
# for it so default completion won't use numeric completion.
# Insert this alias in front to activate numeric completion.
NUMERIC_COMPLETE_alias="${NUMERIC_COMPLETE_alias:-n}"
NUMERIC_COMPLETE_pager=()

# ------------------------------
# track the current choices.
# ------------------------------
_NC_choices=()

# ------------------------------
# cache the directory reads + lengths in this array
# ------------------------------
# idx 0: Command line up to the last cursor
# idx 1: directory fullpath
# choices, lengths
_NC_cache=()

# ------------------------------
# Readline Settings
# ------------------------------
# Override bind to set cached settings whenever called.
if [[ "$(type _NC_orig_bind 2>/dev/null)" != 'function' ]]
then
	case "$(type -t bind)" in
	# possible values: `alias', `keyword', `function', `builtin', `file' or `'
		file|builtin)
			# Generally should only ever be in this case.
			_NC_orig_bind()
			{
				command bind "${@}"
			}
			;;
		function)
			if [[ ! "$(declare -f bind)" =~ .*'_NC_orig_bind ' ]]
			then
				printf 'Warning, experimental overriding function bind.\n'
				eval _NC_orig_"$(declare -f bind)"
			else
				printf 'bind is a function that already references _NC_orig_bind\n'
			fi
			;;
		alias)
			printf 'Warning, experimental overriding alias bind.\n'
			_NC_orig_bind_alias=$(alias bind)
			_NC_orig_bind()
			{
				alias bind="${_NC_orig_bind_alias}"
				bind
				unalias bind
			}
			unalias bind
			;;
		*)
			printf 'Warning, overriding bind but not sure if it will work.\n'
			_NC_orig_bind()
			{
				command bind "${@}"
			}
			;;
	esac

	bind()
	{
		_NC_orig_bind "${@}"
		local ret=$?
		local data="$(_NC_orig_bind -v)"
		_NC_completion_ignore_case="${data#*completion-ignore-case }"
		_NC_completion_ignore_case="${_NC_completion_ignore_case:0:2}"

		_NC_show_mode_in_prompt="${data#*show-mode-in-prompt }"
		_NC_show_mode_in_prompt="${_NC_show_mode_in_prompt:0:2}"
		return "${ret}"
	}
	bind
fi


# ------------------------------
# Functions
# ------------------------------

# ------------------------------
# keycode to character conversion
# ------------------------------
_NC_num2char() # <num> [output_varname=RESULT]
# Convert a number into a character and store in output_varname
{
	local -n _NC__num2char_val="${2:-RESULT}"
	printf -v _NC__num2char_val '%x' "${1}"
	printf -v _NC__num2char_val '\x'"${_NC__num2char_val}"
}
_NC_char2num() # <num> [output_varname=RESULT]
# Convert a character into a number and store in output_varname
{
	local -n _NC__char2num_val="${2:-RESULT}"
	printf -v _NC__char2num_val '%d' "'${1}"
}

#Set the pager for displaying choices.
NUMERIC_COMPLETE_set_pager()
# Set NUMERIC_COMPLETE_pager variable to use less if available.
{
	NUMERIC_COMPLETE_pager=()
	local lessname lessver lessother
	if read lessname lessver lessother < <(less --version 2>&1)
	then
		if [[ "${lessver}" =~ ^[0-9]+$ ]]
		then
			if [[ "${lessver}" -ge 600 ]]
			then
				NUMERIC_COMPLETE_pager=(less -R -~ --header 2)
			else
				NUMERIC_COMPLETE_pager=(less -R -~ +1)
			fi
		fi
	fi
}

# allow pushing/popping changing shopt values.
_NC_shopt_stack=()
_NC_push_shopt() # [(-|+)setting_name] ...
# Set(+) or unset(-) shopt options
{
	local choice name add turnon= turnoff=
	for choice in "${@}"
	do
		add="${choice:0:1}"
		name="${choice:1}"

		if [[ "${BASHOPTS}" =~ ^.*"${name}".*$ ]]
		then
			turnon+=" ${name}"
		else
			turnoff+=" ${name}"
		fi

		if [[ "${add}" = '-' ]]
		then
			shopt -u "${name}"
		else
			shopt -s "${name}"
		fi
	done
	choice="${#_NC_shopt_stack[@]}"
	if [[ "${#turnon}" -gt 0 ]]
	then
		_NC_shopt_stack+=("shopt -s ${turnon}")
	fi

	if [[ "${#turnoff}" -gt 0 ]]
	then
		_NC_shopt_stack+=("shopt -u ${turnoff}")
	fi
	_NC_shopt_stack+=("${choice}")
}

_NC_pop_shopt()
# Reset shopt values to before the last push_shopt
{
	local target=${_NC_shopt_stack[-1]}
	unset '_NC_shopt_stack[-1]'
	while [[ "${#_NC_shopt_stack[@]}" -gt "${target}" ]]
	do
		${_NC_shopt_stack[-1]}
		unset '_NC_shopt_stack[-1]'
	done
}

_NC_pathsplit() # <path> [dname_var] [basename_var]
# Parse <path> into dirnme and basename.
# dirname will be a full path as obtained from ${PWD} and end with a /.
{
	local -n _NC__dname="${2:-dname}" _NC__bname="${3:-bname}"
	if [[ "${1:${#1}-1}" = '/' ]]
	then
		_NC__dname="${1}"
		_NC__bname=''
	else
		_NC__dname="${1%/*}"
		_NC__bname="${1##*/}"
		if [[ "${_NC__dname}" = "${1}" ]]
		then
			_NC__dname=''
		else
			_NC__dname+='/'
		fi
	fi
	if [[ "${_NC__dname:0:1}" != '/' ]]
	then
		_NC__dname="${PWD}/${_NC__dname}"
	fi
}

_NC_max() # <int_array_name> <start> <stop> [output=RESULT]
# Calculate the maximum value from [start, stop).
{
	local -n _NC__output="${4:-RESULT}" _NC__array="${1}"
	local stop=$((${3} < "${#_NC__array[@]}" ? "${3}" : ${#_NC__array[@]}))
	if (("${2}" >= "${stop}"))
	then
		_NC__output=
		return
	fi
	local idx="${2}"
	_NC__output="${_NC__array[idx]}"
	while ((idx < "${stop}"))
	do
		if ((_NC__output < "${_NC__array[idx]}"))
		then
			_NC__output="${_NC__array[idx]}"
		fi
		((++idx))
	done
}

_NC_calc_shape() # <strwidth_array> <start> <stop> <termwidth> <minpad>
#                  [rowout=rows] [colwidths=colwidths] [prewidth=prewidth]
# Calculate the rows and columns to display strings with lengths given
# in <strwidth_array> from [<start>, <stop>) such that the result is
# at most <termwidth> wide with at least <minpad> spaces bewteen each
# column.  A column will consist of a prefix of width <prewidth> and
# the corresponding text.  The outputs will be <rowout>: the number of
# rows, <colout>: the number of columns, <colwidth>: an array of the
# widths of each column (text portion only), and <prewidth>: the width
# of the prefix for each column.  The net width will be at least
# <prewidth>*<colout> + sum(${colwidths[@]}) + (<colout> - 1) * <minpad>
{
	local -n _NC__arr="${1}"
	local start="${2}" stop="${3}" termwidth="${4}" minpad="${5}"
	local -n _NC__rows="${6:-rows}" \
		_NC__colwidths="${7:-colwidths}" _NC__prewidth="${8:-prewidth}"
	_NC__colwidths=()
	local nchoices=$((stop - start)) maxwidth
	_NC_max _NC__arr "${2}" "${3}" maxwidth
	_NC__prewidth=$(("${#nchoices}" + 1))
	local colcheck=$((termwidth / (maxwidth + _NC__prewidth)))
	while ((colcheck >= 1
		&& ((_NC__prewidth + maxwidth + minpad)*colcheck ) - minpad > termwidth))
	do
		((--colcheck))
	done
	if ((colcheck == 0))
	then
		_NC__rows=nchoices
		_NC__colwidths=("${maxwidth}")
		return
	elif ((colcheck >= nchoices))
	then
		_NC__rows=1
		_NC__colwidths=("${_NC__arr[@]:start:stop-start}")
		return
	fi
	_NC__rows="$(((nchoices/colcheck) + ((nchoices % colcheck) > 0)))"
	while ((_NC__rows*colcheck - nchoices >= _NC__rows))
	do
		((--colcheck))
		_NC__rows="$(((nchoices / colcheck) + ((nchoices % colcheck) > 0)))"
	done
	while (("${#_NC__colwidths[@]}" < colcheck))
	do
		_NC__colwidths+=("${maxwidth}")
	done
	while ((colcheck < nchoices && termwidth >= maxwidth + colcheck*(_NC__prewidth+minpad) - minpad))
	do
		local rowcheck=$((nchoices/colcheck + (nchoices % colcheck > 0)))
		if ((rowcheck*colcheck - nchoices < nrows))
		then
			local netwidth=0 idx=${start} curwidth tcolwidths=() \
				textspace=$((termwidth - (colcheck*(minpad+_NC__prewidth) - minpad)))
			while ((idx < stop && netwidth < textspace))
			do
				_NC_max _NC__arr ${idx} $((idx+rowcheck < stop ? idx+rowcheck : stop )) curwidth
				tcolwidths+=("${curwidth}")
				((netwidth += curwidth))
				((idx += rowcheck))
			done
			if ((netwidth <= textspace && idx >= stop))
			then
				_NC__rows="${rowcheck}"
				_NC__colwidths=("${tcolwidths[@]}")
			fi
		fi
		((++colcheck))
	done
}

_NC_count_lines() # <text> <width> [out=RESULT]
# Count the number of lines taking \n and termwidth into consideration.
{
	local text="${1}" width="${2}"
	local -n _NC__out="${3:-RESULT}"
	_NC__out=0
	while (("${#text}" > 0))
	do
		local seg="${text%%$'\n'*}"
		if (("${#seg}" == 0))
		then
			((++_NC__out))
		else
			((_NC__out += "${#seg}" / width + ("${#seg}" / width > 0)  ))
		fi
		if ((${#text} == "${#seg}" + 1))
		then
			((++_NC__out))
		fi
		text="${text:${#seg}+1}"
	done
}

_NC_mimic_prompt() # <width>
# Mimic prompt text and commandline (needs bash >= 4.4)
# Expect termwidth to be defined to columns of terminal
{
	local pre=
	if [[ "${_NC_show_mode_in_prompt}" = 'on' ]]
	then
		pre+=' '
	fi
	local save=$'\e[s'
	if (("${BASH_VERSINFO[0]:-3}" > 4 || ("${BASH_VERSINFO[0]:-3}" == 4 && "${BASH_VERSINFO[1]:-3}" >= 4)))
	then
		local numlines
		_NC_count_lines "${PS1@P}${pre}${COMP_LINE}" "${1}" numlines
		local restore=$'\e['"${numlines}"A
		while ((numlines > 0))
		do
			printf '\n'
			((--numlines))
		done
		printf '%s' \
			"${restore}" \
			"${PS1@P}" \
			"${pre}"
	fi
	printf '%s' \
		"${COMP_LINE:0:COMP_POINT}" \
		$'\e[s' \
		"${COMP_LINE:COMP_POINT}" \
		$'\e[u'
}

# Calculate string widths, supporting unicode.
# https://stackoverflow.com/questions/36380867/how-to-get-the-number-of-columns-occupied-by-a-character-in-terminal
_NC_STRLEN_LUT=(
	126     1   159     0   687     1   710     0   711     1
	727     0   733     1   879     0   1154    1   1161    0
	4347    1   4447    2   7467    1   7521    0   8369    1
	8426    0   9000    1   9002    2   11021   1   12350   2
	12351   1   12438   2   12442   0   19893   2   19967   1
	55203   2   63743   1   64106   2   65039   1   65059   0
	65131   2   65279   1   65376   2   65500   1   65510   2
	120831  1   262141  2   1114109 1
)

#_NC_find_length()
# linear search impl
#{
#	local -n _NC__out="${2:-RESULT}"
#	if (("${1}" == 0xf || "${1}" == 0xe))
#	then
#		_NC__out=0
#		return
#	fi
#	local idx=0 count="${#_NC_STRLEN_LUT[@]}"
#	while ((idx < count))
#	do
#		if (("${1}" <= "${_NC_STRLEN_LUT[idx]}"))
#		then
#			_NC__out="${_NC_STRLEN_LUT[idx+1]}"
#			return
#		fi
#		((idx+=2))
#	done
#}

_NC_find_length()
# binary search impl
{
	local -n _NC__out="${2:-RESULT}"
	if (("${1}" == 0xf || "${1}" == 0xe))
	then
		_NC__out=0
		return
	elif (("${1}" <= "${_NC_STRLEN_LUT[0]}"))
	then
		# common case
		_NC__out="${_NC_STRLEN_LUT[1]}"
		return
	fi
	local low high mid
	low=0
	high=$(("${#_NC_STRLEN_LUT[@]}" / 2))
	while ((low < high))
	do
		((mid = (high + low) / 2))
		if (("${1}" < "${_NC_STRLEN_LUT[mid*2]}"))
		then
			((high = mid))
		elif (("${1}" > "${_NC_STRLEN_LUT[mid*2]}"))
		then
			((low = mid+1))
		else
			_NC__out="${_NC_STRLEN_LUT[mid*2 + 1]}"
			return
		fi
	done
	_NC__out="${_NC_STRLEN_LUT[mid*2+1]}"
}



if (( "${BASH_VERSINFO[0]:-4}" > 5 || ("${BASH_VERSINFO[0]:-4}" == 5 && ${BASH_VERSINFO[1]:-1} >= 2 )))
then
	_NC_strlen()
	{
		local -n _NC__width="${2:-RESULT}"
		_NC__width=0
		local chars char charlen
		_NC_push_shopt +patsub_replacement
		printf -v chars '%d ' ${1//?/\'& }
		_NC_pop_shopt
		for char in ${chars}
		do
			_NC_find_length "${char}" charlen
			((_NC__width += charlen))
		done
	}
else
	_NC_strlen() # <string> [result=RESULT]
	# Calculate the length of a string considering utf8 unicode
	# but no ansi escape codes. remove them first.
	{
		local -n _NC__width="${2:-RESULT}"
		local idx=0 length="${#1}" char charlen
		_NC__width=0
		while ((idx < length))
		do
			printf -v char '%d' "'${1:idx:1}"
			_NC_find_length "${char}" charlen
			((_NC__width += charlen))
			((++idx))
		done
	}
fi


_NC_read_dir() # <dname>
# Search directory and process results.
{
	local dname="${1}"
	_NC_cache=("${_NC_cache[0]}" "${dname}")
	local lsargs=()
	if [[ -n "${dname}" ]]
	then
		lsargs=("${dname}")
	fi
	readarray -O 2 -t _NC_cache < <(ls -Ap --color=always "${lsargs[@]}" 2>/dev/null)
	_NC_push_shopt +extglob
	local raw=("${_NC_cache[@]//$'\e'\[*([0-9;])[a-zA-Z]}")
	_NC_pop_shopt
	local idx=2 end="${#_NC_cache[@]}" length
	while ((idx < end))
	do
		_NC_strlen "${raw[idx]}" length
		_NC_cache+=("${length}")
		((++idx))
	done
}

_NC_refine_choices() # <base>
# Refine choices into _NC_choices.
# If _NC_choices is not empty, then refine those choices.
# Otherwise, refine choices taken from the _NC_cache.
# After refinement, the first half of _NC_choices will be a sequence of
# choices that share a prefix with <base>.  The second half will be a
# one to one sequence of visual string lengths per matching choice.
{
	if (("${#_NC_choices[@]}" > 0))
	then
		# refine choices from chosen
		local start=0 mid=$(("${#_NC_choices[@]}" / 2))
		local -n _NC__choice_src=_NC_choices
	else
		# newly refined choices
		local start=2 mid=$((1 + ("${#_NC_cache[@]}" / 2)))
		local -n _NC__choice_src=_NC_cache
	fi
	local assign=0 idx="${start}"
	while ((idx < mid))
	do
		# ignore ANSI color codes when matching
		if [[ "${_NC__choice_src[idx]}" =~ ^($'\e'\[[0-9:;]*[a-zA-Z])*"${1}".*($'\e'\[[0-9:;]*[a-zA-Z])*/?$ ]]
		then
			_NC_choices[assign]="${_NC__choice_src[idx]}"
			_NC_choices[mid + assign]="${_NC__choice_src[mid + idx - start]}"
			((++assign))
		fi
		((++idx))
	done
	idx=0
	while ((idx < assign))
	do
		_NC_choices[assign+idx]="${_NC_choices[mid+idx]}"
		((++idx))
	done
	idx=$((assign*2))
	mid=$((mid+assign < "${#_NC_choices[@]}" ? "${#_NC_choices[@]}" : mid+assign))
	while ((idx < mid))
	do
		unset _NC_choices[idx]
		((++idx))
	done
}


# Set COMPREPLY array.
# numeric_complete_set_COMPREPLY [choice (int)] [curword]
_NC_set_COMPREPLY() # <choice (int)> [curword]
# Set COMPREPLY to _NC_choices[<choice>], stripping any ansi color codes.
{
	_NC_push_shopt +extglob
	local basechoice="${_NC_choices[${1}]//$'\e'\[*([0-9:;])[a-zA-Z]}"
	_NC_pop_shopt

	if [[ "${2}" =~ .*/.* ]]
	then
		COMPREPLY=("${2%/*}/${basechoice}")
	else
		COMPREPLY=("${basechoice}")
	fi
	#if [[ "${COMPREPLY[0]:${#COMPREPLY[0]}-1}" != '/' ]]
	#then
	#	COMPREPLY[0]="${COMPREPLY[0]} "
	#fi
}

_NC_print_table() # <arr> <rows> <colwidthsarray> <prewidth> <termwidth>
# Print _NC_choices in rows, cols
# rows: The number of rows to print.
# colwidthsarray: The variable name of an array containing column widths,
#                 1 int per column (text only).
# prewidth: The width for numbering the choices.
# termwidth: The current width of the terminal
{
	local -n _NC__items="${1}" _NC__colwidths="${3}"
	local maxpad=4 rows="${2}" cols="${#_NC__colwidths[@]}" prewidth="${4}"
	local padspace=$(("${5}" - prewidth * cols)) textwidth
	for textwidth in "${_NC__colwidths[@]}"
	do
		((padspace -= textwidth))
	done
	local prepad=('') tmp idx=1
	while ((idx < cols))
	do
		tmp=$((idx * padspace / (cols-1)))
		tmp=$((tmp > maxpad ? maxpad : tmp))
		printf -v tmp "%${tmp}s" ''
		prepad+=("${tmp}")
		((++idx))
	done

	if [[ -t 1 ]]
	then
		printf 'T'
	else
		printf 'Press \"q\" to return to command ilne.\nThen t'
	fi
	printf 'ype the number for the desired choice and press tab to select.\n\n'

	local currow=0 lenstart=$(("${#_NC__items[@]}" / 2))
	while ((currow < rows))
	do
		local curcol=0
		while ((curcol < cols))
		do
			idx=$(( (curcol*rows) + currow ))
			if ((idx < "${#_NC__items[@]}" / 2))
			then
				rpad=$((_NC__colwidths[curcol] - _NC__items[idx+lenstart]))
				printf "${prepad[curcol]}%${prewidth}s%s%${rpad}s" \
					"${idx} " "${_NC__items[idx]}"
			else
				break
			fi
			((++curcol))
		done
		printf '\n'
		((++currow))
	done
}


_NC_display_choices()
# Display the completion choices in _NC_choices
{
	local termwidth
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
	if (("${#_NC_choices[@]}" > 0))
	then
		local rows colwidths prewidth
		_NC_calc_shape _NC_choices $(("${#_NC_choices[@]}" / 2)) \
			"${#_NC_choices[@]}" "${termwidth}" 2 rows colwidths prewidth
		if [[ "${#NUMERIC_COMPLETE_pager[@]}" -gt 0 ]]
		then
			_NC_print_table _NC_choices "${rows}" colwidths "${prewidth}" "${termwidth}" \
				| "${NUMERIC_COMPLETE_pager[@]}"
		else
			printf '\n'
			_NC_print_table _NC_choices "${rows}" colwidths "${prewidth}" "${termwidth}"
			if ((COMP_TYPE == 9))
			then
				printf '\n'
				_NC_mimic_prompt "${termwidth}"
			else
				printf '\e[A'
			fi
			restore=
		fi
	fi
}
numeric_complete() {
	 _NC_push_shopt +extglob
	local target="${2/#~*(\/)/${HOME}\/}"
	_NC_pop_shopt
	printf '*\e[D'
	local restore=${COMP_LINE:COMP_POINT:1}
	restore="${restore:- }"
	local extra="${COMP_LINE:0:COMP_POINT}" key choices_idx_offset=2
	extra="${extra#${_NC_cache[0]}}"
	_NC_cache[0]="${COMP_LINE:0:COMP_POINT}"
	_NC_num2char "${COMP_KEY}" key
	if [[ "${extra}" != "${COMP_LINE:0:COMP_POINT}" \
		&& "${extra}" =~ ^[0-9]+$ \
		&& "${extra}" -ge 0 \
		&& "${extra}" -lt $(("${#_NC_choices[@]}")) \
	]]
	then
		_NC_set_COMPREPLY "${extra}" "${2}"
		_NC_choices=()
	else
		if [[ "${key}" != $'\t' || "${NUMERIC_COMPLETE_alias:-n}" = "${1}" ]]
		then
			local dname base
			_NC_pathsplit "${2}" dname base
			if [[ "${dname}" != "${_NC_cache[1]}" ]]
			then
				_NC_read_dir "${dname}"
				_NC_choices=()
			fi
			_NC_refine_choices "${base}"
			if (("${#_NC_choices[@]}" == 2))
			then
				_NC_set_COMPREPLY 0 "${2}"
				_NC_choices=()
			else
				_NC_display_choices
				COMPREPLY=('' ' ')
			fi
		else
			COMPREPLY=()
		fi
	fi
	if [[ -n "${restore}" ]]
	then
		printf '%s\e[D' "${restore}"
	fi
}

alias ${NUMERIC_COMPLETE_alias}=''
complete -o default -o filenames -F numeric_complete ${NUMERIC_COMPLETE_alias}

if [[ -n "${NUMERIC_COMPLETE_default}" ]]
then
	complete -D -o default -o filenames -F numeric_complete
	bind \""${NUMERIC_COMPLETE_prefix}${NUMERIC_COMPLETE_default}"'":complete'
fi
