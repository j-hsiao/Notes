#!/bin/bash

# sidenote: observation
# completion function,
# 	${1} = command
# 	${2} = word(partial?sub?)
#
# 	generally, ${2} is a substring of the actual "word" that completion
# 	should operate on.
# 	ex 1:
# 		'a string[tab]
# 		${2} = a string
# 		word = 'a string
# 	Using ${2}, you lose information that the current word to be completed
# 	is a single-quoted string.
# 	ex 2:
# 		"a string ${param[tab]
# 		${2} = a string ${param
# 		word = "a string ${param
# 	In both cases, the extra "a string" is included in the value.
# 	However, using COMP_WORDS, information about the double-quoted
# 	string is included.
#

# Numeric tab completion.
#
# Generally, I think the c-escape style is visually better, but isn't shell compatible.
# In that case, when tab completing, use c-escape.  When completing to a chosen/single
# value, then replace it with shell-compatible version.
#
# Timing
# In a directory containing:
# 	mkdir {01..1000}
# 	touch {1..999} a\ b
# 	                                                  cygwin          wsl
# 	fnames=(*)                                         0.049          0.001
# 	fnames=(* .*)                                      0.060          0.004
# 	dnames=(*/)                                       12.043          0.003
# 	dnames=(*/ .*/)                                   10.597          0.008
# 	compgen -f >/dev/null                              0.030          0.003
# 	readarray -t fnames < <(compgen -f)                0.160          0.006
# 	readarray -t fnames < <(compgen -d)               50.211          0.009
# 	readarray -t fnames < <(compgen -o default)        0.155          0.005
# 	readarray -t fnames < <(ls -Abp --color=never)     0.252          0.011
# 	readarray -t fnames < <(compgen -o dirnames)      49.875          0.008
# 	readarray -t fnames < <(compgen -o plusdirs)      51.203          0.009
# 	py ls.py                                           0.974          0.173
#
# 	NOTES
# 	ls.py is a python script that uses os.listdir. if -p flag is added, then
# 	os.stat() on each entry to determine whether it is a directory or not.
# 	I tried the bash.exe provided with git for windows, but it's slower than
# 	cygwin for every single case.
#
# 	Most of these provide both files and dirs, but many do not distinguish
# 	between them.  The fastest one that distinguishes between files/dirs is the
# 	ls method.  compogen itself is very fast, but capturing the results requires
# 	command/process substitution, which has a significant slowdown on cygwin.
#
# 	Conclusion:
# 		Without an array glob is the overall most performant method WITHOUT
# 		distinguishing between file and dir.
# 		ls -Abp --color=never is the overal most performant method WITH
# 		distinguishing between file and dir.
#
# 		In the end though, it seems like parsing is still required
# 		ex: hello${HO[tab] fails to do any completions with compgen


# Default cache size
NCMP_CACHE_SIZE=${NCMP_CACHE_SIZE:-10}
. "${BASH_SOURCE[0]/%numeric_complete.sh/util}/shoptstack.sh"
. "${BASH_SOURCE[0]/%numeric_complete.sh/util}/chinfo.sh"
. "${BASH_SOURCE[0]/%numeric_complete.sh/util}/cache.sh"
. "${BASH_SOURCE[0]/%numeric_complete.sh/util}/shparse.sh"
ch_make NCMP_CACHE ${NCMP_CACHE_SIZE}

ncmp_run()
{
	# Set up useful variables but put in function to prevent namespace pollution.
	local NCMP_CACHE_PREFIX=0
	local NCMP_QUERY=$((NCMP_CACHE_PREFIX++))
	local NCMP_COUNT=$((NCMP_CACHE_PREFIX++))
	local declare -n NCMP_DNAME=NCMP_CACHE_index
	local NCMP_CHOICE='NCMP_CACHE_PREFIX'
	local NCMP_LENGTH='NCMP_CACHE_PREFIX + NCMP_CACHE[NCMP_COUNT]'
	local NCMP_REFINE='NCMP_CACHE_PREFIX + NCMP_CACHE[NCMP_COUNT]*2'

	if [[ "${TERM}" = *color* || "${COLORTERM}" = *color* ]]
	then
		local NCMP_BLUE='\e[01;34m'
		local NCMP_RESET='\e[0m'
		local NCMP_INVERT='\e[30;47m'
	else
		local NCMP_BLUE=
		local NCMP_RESET=
		local NCMP_INVERT=
	fi
	"${@}"
}


# "${x/%*\//${NCMP_RESET}${NCMP_BLUE}${x%/}${NCMP_RESET}/}"


# Store internal state
declare -gA NCMP_STATE

# The readline completion-ignore-case and show-mode-in-prompt
# settings are needed to determine numeric completion behavior.
# However, on Cygwin, bind is noticeably very slow.  A solution
# would be to cache the value of the settings into variables.

NCMP_STATE['completion_ignore_case']=
NCMP_STATE['show_mode_in_prompt']=
NCMP_STATE['editing_mode']=
NCMP_STATE['show_all_if_ambiguous']=

ncmp_refresh_readline() {
	# refresh cached readline data.
	local line
	while read line
	do
		case "${line}" in
			*completion-ignore-case*)
				NCMP_STATE['completion_ignore_case']="${line#*completion-ignore-case }"
				;;
			*show-mode-in-prompt*)
				NCMP_STATE['show_mode_in_prompt']="${line#*show-mode-in-prompt }"
				;;
			*editing-mode*)
				NCMP_STATE['editing_mode']="${line#*editing-mode }"
				;;
			*show-all-if-ambiguous*)
				NCMP_STATE['show_all_if_ambiguous']="${line#*show-all-if-ambiguous }"
				;;
		esac
	done < <(command bind -v)
}

if ! declare -f ncmp_orig_bind &>/dev/null
then
	case "$(type -t bind)" in
		file|builtin)
			ncmp_orig_bind() {
				command bind "${@}"
			}
			;;
		function)
			if [[ ! "$(declare -f bind)" =~ .*'ncmp_orig_bind ' ]]
			then
				printf 'Warning, experimental overriding function bind.\n'
				eval ncmp_orig_"$(declare -f bind)"
			else
				printf 'bind is a function that already references ncmp_orig_bind\n'
			fi
			;;
		alias)
			printf 'Warning, experimental overriding alias bind.\n'
			NCMP_STATE['bind_alias']=$(alias bind)
			ncmp_orig_bind() {
				alias bind="${NCMP_STATE['bind_alias']}"
				bind
				unalias bind
			}
			unalias bind
			;;
		*)
			printf 'Warning, overriding unknown bind implementation.'
			ncmp_orig_bind() { command bind "${@}"; }
			;;
	esac
	bind() {
		ncmp_orig_bind "${@}"
		local ret=$?
		ncmp_refresh_readline
		return "${ret}"
	}
	if [[ "${0}" != "${BASH_SOURCE[0]}" ]]
	then
		bind
	fi
fi
ncmp_refresh_readline

ncmp_pathsplit() # <path> [dname_var=dname] [basename_var=bname] [fulldir=dpath]
# Parse <path> into dir name and base name and full normalized dir name.
# The results are stored in the corresponding variables if provided.
# NOTE: dir1/dir2 will be split as dir1/ and dir2
#       dir1/dir2/ will be split as dir1/dir2/ and ''
{
	local -n ncmpps__dname="${2:-dname}" ncmpps__bname="${3:-bname}" ncmpps__dpath="${4:-dpath}"
	[[ "${1}" =~ (.*/)?(.*) ]] # load into BASH_REMATCH
	ncmpps__dname="${BASH_REMATCH[1]}"
	ncmpps__bname="${BASH_REMATCH[2]}"
	ss_push extglob
	ncmpps__dpath="${ncmpps__dname//+(\/)/\/}"
	ncmpps__dpath="${ncmpps__dpath/#~*([^\/])/${HOME}}"
	ss_pop
	if [[ "${ncmpps__dpath:0:1}" != '/' ]]
	then
		ncmpps__dpath="${PWD}/${ncmpps__dpath}"
	fi
}

ncmp_find() # <string> <query> [out=RESULT]
{
	# Find the position of <query> in <string> and assign to [out]
	local -n ncmpf__out="${3:-RESULT}"
	local curidx=-1
	local total="${#1}"
	local removed="${1#*"${2}"}"
	if ((${#removed} == total))
	then
		ncmpf__out=-1
	else
		((ncmpf__out = ${#1} - ${#2} - ${#removed}))
	fi
}




ncmp_expand_prompt() # [prompt=${PS1}] [out=RESULT]
{
# Expand a prompt string
	local -n ncmpep__out="${2:-RESULT}"
	ncmpep__out="${1:-${PS1}}"

	if (("${BASH_VERSINFO[0]:-3}" > 4 || ("${BASH_VERSINFO[0]:-3}" == 4 && "${BASH_VERSINFO[1]:-3}" >= 4)))
	then
		ncmpep__out="${ncmpep__out@P}"
		return
	fi

	local parts=()
	local idx=0 stop
	while ((idx < "${#ncmpep__out}"))
	do
		ncmp_find "${ncmpep__out:idx}" '\' stop
		if ((stop < 0))
		then
			parts+=("${ncmpep__out:idx}")
			break
		elif ((stop > 0))
		then
			parts+=("${ncmpep__out:idx:stop}")
			((idx += stop))
		fi
		case "${ncmpep__out:idx}" in
			'\a'*|'\e'*|'\n'*|'\r'*)
				printf -v "parts[${#parts[@]}]" "${ncmpep__out:idx:2}"
				;;
			'\d'*)
				parts+=("$(date '+%a %b %d')")
				;;
			'\D{'*)
				local stop
				ncmp_find "${ncmpep__out:idx+3}" '}' stop
				if ((stop >= 0))
				then
					parts+=("$(date "+${ncmpep__out:idx+3:stop}")")
					((idx += stop + 4))
				else
					parts+=("$(date "+${ncmpep__out:idx+3}")")
					idx="${#ncmpep__out}"
				fi
				continue
				;;
			'\h'*)
				parts+=("${HOSTNAME%%.*}")
				;;
			'\H'*)
				parts+=("${HOSTNAME}")
				;;
			'\j'*)
				parts+=("$(jobs|wc -l)")
				;;
			'\l'*)
				parts+=("$(tty)")
				parts[-1]="${parts[-1]##*/}"
				;;
			'\s'*)
				parts+=("${SHELL##*/}")
				;;
			'\t'*)
				parts+=("$(date '+%H:%M:%S')")
				;;
			'\T'*)
				parts+=("$(date '+%I:%M:%S')")
				;;
			'\@'*)
				parts+=("$(date '+%I:%M %p')")
				;;
			'\A'*)
				parts+=("$(date '+%H:%M')")
				;;
			'\u'*)
				parts+=("${USER}")
				;;
			'\v'*)
				parts+=("${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}")
				;;
			'\V'*)
				parts+=("${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}")
				;;
			'\w'*)
				parts+=("${PWD/#"${HOME}"/${PROMPT_DIRTRIM:-~}}")
				;;
			'\W'*)
				if [[ "${PWD}" = "${HOME}" ]]
				then
					parts+=('~')
				else
					parts+=("${PWD##*/}")
				fi
				;;
			'\!'*)
				parts+=("${HISTCMD}")
				;;
			'\#'*)
				# TODO: the command number number of this command
				# doesn't seem to be any way to get this, but ti
				# also doesn't seem all that useful either...
				;;
			'\$'*)
				if ((UID == 0))
				then
					parts+=('#')
				else
					parts+=('$')
				fi
				;;
			'\'[0-9][0-9][0-9]*)
				printf -v "parts[${#parts[@]}]" "${ncmpep__out:idx:4}"
				((idx += 4))
				continue
				;;
			'\\'*)
				parts+=('\')
				;;
			'\['*|'\]'*)
				;;
			*)
				parts+=('\')
				((++idx))
				continue
				;;
		esac
		((idx += 2))
		# read dummy || return
	done
	printf '"%s"\n' "${parts[@]}"
	printf -v "${2:-RESULT}" '%s' "${parts[@]}"
}


ncmp_max() # <int_array_name> [start=0] [stop=end] [output=RESULT]
{
	# Calculate the maximum value from [start, stop).
	# If the range is empty, then output will be empty.
	local -n ncmpmx__array="${1}" ncmpmx__output="${4:-RESULT}"
	local start="${2:-0}" stop="${3:-${#ncmpmx__array[@]}}"
	((stop = stop < ${#ncmpmx__array[@]} ? stop : ${#ncmpmx__array[@]}))
	if (("${start}" >= "${stop}"))
	then
		ncmpmx__output=
		return
	fi
	ncmpmx__output="${ncmpmx__array[start]}"
	while ((start < stop))
	do
		if ((ncmpmx__output < "${ncmpmx__array[start]}"))
		then
			ncmpmx__output="${ncmpmx__array[start]}"
		fi
		((++start))
	done
}

ncmp_min() # <int_array_name> [start=0] [stop=end] [output=RESULT]
{
	# Calculate the minimum value from [start, stop).
	# If the range is empty, then output will be empty.
	local -n ncmpmn__array="${1}" ncmpmn__output="${4:-RESULT}"
	local start="${2:-0}" stop="${3:-${#ncmpmn__array[@]}}"
	((stop = stop < ${#ncmpmn__array[@]} ? stop : ${#ncmpmn__array[@]}))
	if (("${start}" >= "${stop}"))
	then
		ncmpmn__output=
		return
	fi
	ncmpmn__output="${ncmpmn__array[start]}"
	while ((start < stop))
	do
		if ((ncmpmn__output > "${ncmpmn__array[start]}"))
		then
			ncmpmn__output="${ncmpmn__array[start]}"
		fi
		((++start))
	done
}

ncmp_count_lines() # <text> [width=${COLUMNS}] [out=RESULT]
{
	# Count the number of lines <text> would take in a terminal of <width>.
	local ncmpcl__text="${1}" ncmpcl__width="${2:-${COLUMNS}}"
	local -n ncmpcl__out="${3:-RESULT}"
	ncmpcl__out=1
	local col=0 idx=0
	while ((idx < "${#ncmpcl__text}"))
	do
		if [[ "${ncmpcl__text:idx:1}" = $'\n' ]]
		then
			((col=0))
			((++ncmpcl__out))
		else
			local clen
			ci_charwidth "${ncmpcl__text:idx:1}" clen
			if ((col + clen <= ncmpcl__width))
			then
				((col += clen))
			else
				((col = clen))
				((++ncmpcl__out))
			fi
		fi
		((++idx))
	done
}

ncmp_escape2shell() # <text> [out=RESULT]
{
	# Convert <text> from ls -b style escaping
	# to shell-style escaping
	local -n ncmpe2s__out="${2:-RESULT}"
	printf -v ncmpe2s__out "${1//'\ '/ }"
	# ${ncmpe2s__tmp@Q} always adds quotes regardless of whether they are necessary or not.
	# prefer printf -v in this case
	printf -v ncmpe2s__out '%q' "${ncmpe2s__out}"
}

NCMP_CACHE_STATE=3

ncmp_read_dir() # <dname> [force=]
{
	# Read and preprocess <dname> into the cache.
	# The cache (NCMP_CACHE) will contain:
	# 1. The current query
	# 2. The number of entries
	# 3. The display entries (maybe with colors, etc)
	# 4. the raw entries (no colors) for length + searching
	# 5. the display lengths.
	#
	# If [force] is not empty, then force re-reading the
	# directory.  This is useful if there was some change
	# to a directory and the cache is outdated.
	if ! ch_get NCMP_CACHE "${1}" || [[ -n "${2}" ]]
	then
		# NOTE: Tried implementing to find entries with a common prefix
		# but it was very slow, linear search much faster, tested up to
		# 1000 items.

		ss_push extglob globasciiranges
		NCMP_CACHE=()

		# Sidenote, using compgen can be very very slow...
		# ls = 0.18 seconds, but compgen = 3 seconds if compgen -df -o plusdirs (to distinguish directories)
		# or compgen -df 2 seconds
		# If this is the case, ls seems to be way more preferrable to compgen
		# but compgen does give some benefits like no need to implement
		# parsing partial bash/readline parsing.

		readarray -O${NCMP_CACHE_STATE} -t NCMP_CACHE < <(ls -Apb --color="${NUMERIC_COMPLETE_color:-never}" "${1}" 2>/dev/null)
		# https://en.wikipedia.org/wiki/ANSI_escape_code
		# [0x30–0x3F]*  (0–9:;<=>?)
		# [0x20–0x2F]*  ( !"#$%&'()*+,-./)
		# 0x40–0x7E     (@A–Z[\]^_`a–z{|}~)

		if [[ "${NUMERIC_COMPLETE_color:-never}" = 'never' ]]
		then
			NCMP_CACHE+=("${NCMP_CACHE[@]}")
			if [[ -z "${NUMERIC_COMPLETE_color}" ]]
			then
				#Color directories indicated by the -p flag
				local idx="$((${#NCMP_CACHE[@]} / 2))"
				while ((--idx > 0))
				do
					if [[ "${NCMP_CACHE[idx+NCMP_CACHE_STATE]: -1}" = '/' ]]
					then
						NCMP_CACHE[idx+NCMP_CACHE_STATE]=$'\e[0m\e[01;34m'"${NCMP_CACHE[idx+NCMP_CACHE_STATE]%/}"$'\e[0m/'
					fi
				done
			fi
		else
			NCMP_CACHE+=("${NCMP_CACHE[@]//$'\e['*(['0'-'?'])*(['!'-'/'])['@'-'~']}")
		fi
		NCMP_CACHE[1]="$((${#NCMP_CACHE[@]}/2))"
		ci_strdisplaylens NCMP_CACHE $((NCMP_CACHE[1]*2 + NCMP_CACHE_STATE)) \
		"${NCMP_CACHE[@]:NCMP_CACHE[1]+NCMP_CACHE_STATE:NCMP_CACHE[1]}"
		ss_pop
	fi
}

ncmp_load_matches() # <query>
{
	# Load matches of <query> (raw index) into the end of NCMP_CACHE.
	# NCMP_CACHE[0] should be the last query if applicable.
	# <query> would be the new query.
	#
	# If readline completion-ignore-case is on, then if query is all
	# lower case, ignore case.  If query contains upper case, then
	# match case.  Otherwise, only match exact.

	# side note... This generally seems to be quite fast,
	# maybe refining previous match is not necessary?
	local out=$((NCMP_CACHE[1]*3 + NCMP_CACHE_STATE))
	if [[ -z "${1}" ]]
	then
		local idx=$((NCMP_CACHE[1] + NCMP_CACHE_STATE - 1)) end=$((NCMP_CACHE[1]*2 + NCMP_CACHE_STATE))
		while ((++idx < end))
		do
			NCMP_CACHE[out++]="${idx}"
		done
		NCMP_CACHE[0]=''
		return
	fi

	if [[ "${NCMP_STATE['completion_ignore_case']}" = 'on' && "${1,,}" = "${1}" ]]
	then
		local query="${1^^}"
		if [[ "${1#"${NCMP_CACHE[0]}"}" = "${1}" ]]
		then
			local idx=$((NCMP_CACHE[1] + NCMP_CACHE_STATE - 1)) end=$((NCMP_CACHE[1]*2 + NCMP_CACHE_STATE)) candidate
			while ((++idx < end))
			do
				candidate="${NCMP_CACHE[idx]^^}"
				if [[ "${candidate#"${query}"}" != "${candidate}" ]]
				then
					NCMP_CACHE[out++]="${idx}"
				fi
			done
		else
			local idx="${out}" end="${#NCMP_CACHE[@]}" candidate
			while ((idx < end))
			do
				candidate="${NCMP_CACHE[NCMP_CACHE[idx]]^^}"
				if [[ "${candidate#"${query}"}" != "${candidate}" ]]
				then
					NCMP_CACHE[out++]="${NCMP_CACHE[idx]}"
				fi
				((++idx))
			done
		fi
	else
		if [[ "${1#"${NCMP_CACHE[0]}"}" = "${1}" ]]
		then
			local idx=$((NCMP_CACHE[1] + NCMP_CACHE_STATE - 1)) end=$((NCMP_CACHE[1]*2 + NCMP_CACHE_STATE))
			while ((++idx < end))
			do
				if [[ "${NCMP_CACHE[idx]#"${1}"}" != "${NCMP_CACHE[idx]}" ]]
				then
					NCMP_CACHE[out++]="${idx}"
				fi
			done
		else
			local idx="${out}" end="${#NCMP_CACHE[@]}" candidate
			while ((idx < end))
			do
				candidate="${NCMP_CACHE[NCMP_CACHE[idx]]}"
				if [[ "${candidate#"${1}"}" != "${candidate}" ]]
				then
					NCMP_CACHE[out++]="${NCMP_CACHE[idx]}"
				fi
				((++idx))
			done
		fi
	fi
	NCMP_CACHE[0]="${1}"
	end=${#NCMP_CACHE[@]}
	while ((out < end))
	do
		unset NCMP_CACHE[out++]
	done
}

ncmp_mimic_prompt() # <command> <pos>
{
	# Mimic the bash prompt.
	# Leave the cursor at position <pos> of <command>
	# This is necessary so that the choices can be displayed and the cursor
	# ends up in an appropriate position to continue typing the command.
	local pre=
	if [[ "${NCMP_STATE['show_mode_in_prompt']}" = 'on' ]]
	then
		if [[ "${NCMP_STATE['editing_mode']}" = 'emacs' ]]
		then
			pre+='@'
		else
			pre+='(ins)'
		fi
	fi
	# @P operator requires bash 4.4+
	local prompt
	ncmp_expand_prompt "${PS1}" prompt
	# \e[s saves position on screen, not in text buffer. If the
	# terminal is scrolled (ex. commandline at the bottom), then
	# the position becomes incorrect.  Thus, ensure the commandline
	# is not at the bottom by printing newlines to ensure no scrolling
	# will occurr (assuming the prompt is not going to exceed the
	# window height).  Using \b does not work because it does not wrap
	# up to the previous line.
	[[ "${prompt}" =~ (.*$'\n')?(.*) ]]
	prompt="${BASH_REMATCH[1]}${pre}${BASH_REMATCH[2]}" 
	local numlines
	ncmp_count_lines "${prompt}${1}" '' numlines
	if ((numlines > 1))
	then
		printf "\\r${prompt}${1}\\e[$((numlines-1))A"
	fi
	printf "\\r${prompt}"

	# printf "${1:0:${2}}"$'\e[s'"${1:${2}}"$'\e[u'
	# wiki says \e7 \e8 are more widely supported
	# than \e[s and \e[u
	printf "${1:0:${2}}"$'\e7'"${1:${2}}"$'\e8'
}

ncmp_cols_viable() # <strwidth_array> <numcols> <width> [colwidths=RESULT]
{
	# Check that <numcols> columns of <strwidth_array>
	# can fit within <width>
	local -n ncmpcv__arr="${1}" ncmpcv__colwidths="${4:-RESULT}"
	local cols="${2}" width="${3}"

	local rows=$(((${#ncmpcv__arr[@]} / cols) + (${#ncmpcv__arr[@]} % cols > 0)))
	if ((cols != (${#ncmpcv__arr[@]} / rows) + (${#ncmpcv__arr[@]} % rows > 0)))
	then
		return 1
	fi

	local col=0 total=0
	local start=0
	ncmpcv__colwidths=()
	while ((col < ${cols}))
	do
		local stop=$(((col+1)*rows))
		ncmp_max "${1}" "${start}" "${stop}" ncmpcv__colwidths[col]
		((total += ncmpcv__colwidths[col++]))
		((start = stop))
	done
	return $((total > width))
}
ncmp_calcfmt() # <strwidth_array> [termwidth=${COLUMNS}] [minpad=1] [style='\e[30;47m%d.\e[0m ']
               # [fmt=fmt]
{
	# Calculate the printf format strings per column.
	# The formats use ANSI escape codes to place the column text in the
	# right position.
	#
	# arguments:
	# 	<strwidth_array>: the array of string widths
	# 	[termwidth]: the maximum table width.
	# 	[minpad]: minimum padding between columns.
	# 	[style]: The numbering style, must contain '%d'
	# 	[fmt]: The output array variable name to hold the format strings.
	# 	       The length of this array is the number of columns.
	local -n ncmpcf__arr="${1}" ncmpcf__fmt="${5:-fmt}"
	local choices="${#ncmpcf__arr[@]}" termwidth="${2:-${COLUMNS}}" \
		minpad="${3:-1}" prefmt="${4:-\\e[30;47m%d.\\e[0m }"
	if ((!choices)); then ncmpcf__fmt=(); return; fi
	prefmt="${prefmt/\%d/%${#choices}d}"

	local prelen
	printf -v prelen "${prefmt}" "${choices}"
	ss_push extglob globasciiranges
	prelen="${prelen//$'\e['*(['0'-'?'])*(['!'-'/'])['@'-'~']}"
	ss_pop
	ci_strdisplaylen "${prelen}" prelen

	local shortest
	ncmp_min "${1}" '' '' shortest

	local ncols="$((termwidth / shortest + (termwidth%shortest ? 1 : 0)))"
	((ncols = ncols > choices ? choices : ncols))
	while ((ncols*(shortest + prelen + minpad) - minpad > termwidth))
	do
		((--ncols))
	done
	local colwidths=()
	while ((ncols > 0)) && ! ncmp_cols_viable "${1}" "${ncols}" \
		$((termwidth - ncols*(prelen+minpad) + minpad)) colwidths
	do
		((--ncols))
	done
	ncmpcf__fmt=()
	if ((ncols == 0))
	then
		printf -v ncmpcf__fmt[0] '\r%s%%s' "${prefmt}"
	else
		local colstart=1 idx=-1
		while ((++idx < ncols))
		do
			printf -v ncmpcf__fmt[idx] '\\e[%dG%s%%s' "${colstart}" "${prefmt}"
			((colstart+=prelen + colwidths[idx] + minpad))
		done
	fi

}

ncmp_print_matches() # [termwidth=${COLUMNS}] [minpad=1] [style='%d. ']
{
	# Print the loaded choices as a table.
	local strlens=() strs=() idx="$((NCMP_CACHE[1]*3 + NCMP_CACHE_STATE-1))"
	while ((++idx < ${#NCMP_CACHE[@]}))
	do
		strlens+=("${NCMP_CACHE[NCMP_CACHE[idx]+NCMP_CACHE[1]]}")
		strs+=("${NCMP_CACHE[NCMP_CACHE[idx]-NCMP_CACHE[1]]}")
	done
	local fmts=()
	ncmp_calcfmt strlens "${1}" "${2}" "${3}" fmts
	local row=-1 ncols="${#fmts[@]}"
	if ((!ncols)); then return; fi
	local rows="$(((${#strlens[@]} / ncols) + (${#strlens[@]}%ncols > 0)))"
	while ((++row < rows))
	do
		printf '\n'
		local col=-1
		while ((++col < ncols))
		do
			idx=$((row + rows*col))
			if ((idx < ${#strs[@]}))
			then
				printf "${fmts[col]}" $((idx+1)) "${strs[idx]}"
			fi
		done
	done
}

ncmp_last_word() # <text> [out=RESULT] [begin=BEG] [end=END]
{
	# Return the last word for completion.
	# Assume inside a completion function.
	local text="${1}"
	local textlen="${#text}"
	local -n out="${2:-RESULT}"
	local -n beg="${3:-BEG}"
	local -n end="${4:-END}"
	end=0
	while ((0 <= end && end < textlen))
	do
		shparse_parse_word "${text}" 0 "${3}" "${4}" "${end}"
	done
	if ((end < 0))
	then
		if [[ "${1:beg:1}" = ['"`'\'] ]]
		then
			ncmp_last_word "${incomplete:1}" "${@:2}"
			return
		fi
	fi
	COMP_WORDBREAKS="${COMP_WORDBREAKS:-$' \t\n\\\"\\\'><=;|&(:'}"
	out="${1:beg}"
	out="${out##*${COMP_WORDBREAKS}}"
	return
}

ncmp_complete() # <cmd> <word> <preword>
{
	if [[ -n "${NCMP_CACHE[0]}" || -z "${NCMP_CACHE[0]-a}" ]]
	then
		local searched=1
	else
		local searched=0
	fi
	# Ensure NCMP_CACHE[0] is set to avoid length issues.
	NCMP_CACHE[0]="${NCMP_CACHE[0]}"

	if [[ \
		"${2}" =~ ^[[:digit:]]+$ \
		&& "${2}" -gt 0 \
		&& "${2}" -le "$((${#NCMP_CACHE[@]} - (NCMP_CACHE[1]*3 + NCMP_CACHE_STATE)))" \
	]]
	then
		# shortcut to select from the last item, ex. if selecting multiple items from same directory
		local RESULT="${2}"
		ncmp_escape2shell "${NCMP_CACHE[NCMP_CACHE[NCMP_CACHE[1]*3 + NCMP_CACHE_STATE - 1 + RESULT]]}" RESULT
		# Evaluating the offset index within the [] causes error token error message
		# in cygwin bash 5.2.21
		# ncmp_escape2shell "${NCMP_CACHE[NCMP_CACHE[NCMP_CACHE[1]*3 + NCMP_CACHE_STATE - 1 + ${2}]]}" RESULT
		COMPREPLY=("${NCMP_CACHE[2]}${RESULT}")
		return
	fi

	local dname bname dpath
	ncmp_pathsplit "${2}" dname bname dpath
	ncmp_read_dir "${dpath}"
	NCMP_CACHE[2]="${dname}"

	if ((searched))
	then
		if [[ "${NCMP_CACHE[0]}" = "${bname}" ]]
		then
			ncmp_read_dir "${dpath}" a
			NCMP_CACHE[2]="${dname}"
		elif [[ \
			"${bname:0:${#NCMP_CACHE[0]}}" = "${NCMP_CACHE[0]}" \
			&& "${bname:${#NCMP_CACHE[0]}}" =~ ^[[:digit:]]+$ \
			&& "${bname:${#NCMP_CACHE[0]}}" -gt 0 \
			&& "${bname:${#NCMP_CACHE[0]}}" -le "$((${#NCMP_CACHE[@]} - (NCMP_CACHE[1]*3 + NCMP_CACHE_STATE)))" \
		]]
		then
			local RESULT="${bname:${#NCMP_CACHE[0]}}"
			ncmp_escape2shell "${NCMP_CACHE[NCMP_CACHE[NCMP_CACHE[1]*3 + NCMP_CACHE_STATE - 1 + RESULT]]}" RESULT
			# Evaluating the offset index within the [] causes error token error message
			# in cygwin bash 5.2.21
			# ncmp_escape2shell "${NCMP_CACHE[NCMP_CACHE[NCMP_CACHE[1]*3 + NCMP_CACHE_STATE - 1 + ${2}]]}" RESULT
			COMPREPLY=("${dname}${RESULT}")
			unset NCMP_CACHE[0]
			return
		fi
	fi

	ncmp_load_matches "${bname}"

	if ((${#NCMP_CACHE[@]} == NCMP_CACHE[1]*3 + NCMP_CACHE_STATE + 1))
	then
		local RESULT
		ncmp_escape2shell "${NCMP_CACHE[NCMP_CACHE[NCMP_CACHE[1]*3 + NCMP_CACHE_STATE]]}" RESULT
		COMPREPLY=("${dname}${RESULT}")
		unset NCMP_CACHE[0]
	else
		ncmp_print_matches "${COLUMNS:-$(tput cols)}" 2
		if ((COMP_TYPE == 9))
		then
			# numeric completion always behaves as if
			# show-all-if-ambiguous whenever shown, the '' and ' ' are
			# always displayed, resulting in a blank line before the
			# next prompt.  Mimic this behiavor with double newline.
			printf '\n\n'
			ncmp_mimic_prompt "${COMP_LINE}" "${COMP_POINT}"
		fi
		# cannot use an ANSI escape to move the up a line since it will
		# be escaped by bash.
		COMPREPLY=('' ' ')
	fi
}

NUMERIC_COMPLETE_alias="${NUMERIC_COMPLETE_alias:-n}"
NUMERIC_COMPLETE_prefix="${NUMERIC_COMPLETE_prefix:-;}"
NUMERIC_COMPLETE_complete="${NUMERIC_COMPLETE_complete:-l}"
NUMERIC_COMPLETE_normal="${NUMERIC_COMPLETE_normal:-k}"

alias "${NUMERIC_COMPLETE_alias}"=''

complete -o filenames -o noquote -F ncmp_complete "${NUMERIC_COMPLETE_alias}"


# Use a macro to insert the `NUMERIC_COMPLETE_alias` command so that
# numeric completion can be triggered.  This is better than using
# complete -D because commands can already have their own completion
# function.  (Many can have _longopt as the completion function) This
# guarantees that numeric completion will be performed.

# '\e ': set the mark
# '\C-an ' insert the n alias command to trigger completion
# '\C-x\C-x' jump back to mark
# '\C-f\C-f' mark only marks column, not textual position, move forward
#            2 chars to cover the inserted 'n '
# '\t'       trigger completion.
#
# '\e'      enter command mode
# 'mz'      save mark to z
# '0in \e'  insert 'n '
# '`zll'    jump back to position (only saves column position not text position so ll)
# 'a\t'     trigger completion


command bind -m emacs \""${NUMERIC_COMPLETE_prefix}${NUMERIC_COMPLETE_complete}"'":"\e \C-a'"${NUMERIC_COMPLETE_alias}"' \C-x\C-x'"${NUMERIC_COMPLETE_alias//?/\\C-f}"'\C-f\t"'
command bind -m vi-insert \""${NUMERIC_COMPLETE_prefix}${NUMERIC_COMPLETE_complete}"'":"\emz0i'"${NUMERIC_COMPLETE_alias}"' \e`z'"$((${#NUMERIC_COMPLETE_alias}+1))"'la\t"'

# Remove ${#NUMERIC_COMPLETE_alias} worth of characters from the
# beginning and an extra space.  I cannot find any way to check whether
# the command is the alias or not, so it will always just remove a number
# of characters.
command bind -m emacs \""${NUMERIC_COMPLETE_prefix}${NUMERIC_COMPLETE_normal}"'":"'"${NUMERIC_COMPLETE_alias//?/\\C-b}"'\C-b\e \C-a'"${NUMERIC_COMPLETE_alias//?/\\C-d}"'\C-d\C-x\C-x \C-b\C-d"'
command bind -m vi-insert \""${NUMERIC_COMPLETE_prefix}${NUMERIC_COMPLETE_normal}"'":"\e'"$((${#NUMERIC_COMPLETE_alias}+1))h"'mz0'"$((${#NUMERIC_COMPLETE_alias}+1))x"'`za"'


# testing
if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo 'Testing splitpath().'
	splitpath_testcases=( \
		'/:/::/' \
		'/bin:/:bin:/' \
		"hello/world:hello/:world:${PWD}/hello/" \
		"hello/world/:hello/world/::${PWD}/hello/world/" \
		"basename::basename:${PWD}/" \
		"/dev/shm:/dev/:shm:/dev/" \
		"/dev/shm/:/dev/shm/::/dev/shm/" \
		":::${PWD}/"\
	)

	for testcase in "${splitpath_testcases[@]}"
	do
		ncmp_pathsplit "${testcase%%:*}"
		[[ "${dname}:${bname}:${dpath}" = "${testcase#*:}" ]] && echo pass || printf 'fail\n\tgot : "%s"\n\twant: "%s"\n' "${dname}:${bname}" "${testcase#*:}"
	done

	echo 'Testing max().'
	#        0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8
	testarr=(6 5 1 2 8 9 7 6 1 2 9 3 5 7 1 2 9 8 4 1 8 3 4 5 4 3 6 7 1 0 2 3 4 0 9 1 2 3 4)
	ncmp_max testarr
	(( ${RESULT} == 9 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_max testarr 0 5
	(( ${RESULT} == 8 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_max testarr 11 14
	(( ${RESULT} == 7 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_max testarr 0 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"
	ncmp_max testarr 2 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"

	echo 'Testing min()'
	ncmp_min testarr
	(( ${RESULT} == 0 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_min testarr 0 5
	(( ${RESULT} == 1 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_min testarr 11 14
	(( ${RESULT} == 3 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_min testarr 0 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"
	ncmp_min testarr 2 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"

	echo 'Testing cout_lines()'
	ncmp_count_lines hello 11
	((${RESULT} == 1)) && echo pass || echo "fail: ${RESULT} vs 1"
	ncmp_count_lines hello\ world 11
	((${RESULT} == 1)) && echo pass || echo "fail: ${RESULT} vs 1"
	ncmp_count_lines hello\ world 10
	((${RESULT} == 2)) && echo pass || echo "fail: ${RESULT} vs 1"
	ncmp_count_lines hello\ w$'\n'orld 10
	((${RESULT} == 2)) && echo pass || echo "fail: ${RESULT} vs 1"

	strlens=(2 2 2 10 2 2 2 10 2 2 2)
	echo "Testing cols_viable"
	ncmp_cols_viable strlens 3 22 && echo pass || echo "fail"
	ncmp_cols_viable strlens 3 21 && echo fail || echo pass

	# columns   colwidths       prelen  padding     total
	# 2         +10 +10         +4*2    +1          29
	# 3         +10 +10 +2      +4*3    +2          36
	# 4         +2 +10 +10 +2   +4*4    +3          43
	echo "Testing calcfmt"
	ncmp_calcfmt strlens 29 1 '' fmt && ((${#fmt[@]} == 2)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_calcfmt strlens 35 1 '' fmt && ((${#fmt[@]} == 2)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_calcfmt strlens 36 1 '' fmt && ((${#fmt[@]} == 3)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[31G\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_calcfmt strlens 42 1 '' fmt && ((${#fmt[@]} == 3)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[31G\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_calcfmt strlens 43 1 '' fmt && ((${#fmt[@]} == 4)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[8G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[23G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[3]}" = '\e[38G\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_calcfmt strlens 1000 1 '' fmt && ((${#fmt[@]} == 11)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[8G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[15G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[3]}" = '\e[22G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[4]}" = '\e[37G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[5]}" = '\e[44G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[6]}" = '\e[51G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[7]}" = '\e[58G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[8]}" = '\e[73G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[9]}" = '\e[80G\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[10]}" = '\e[87G\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_last_word '"this is a str and /home/us' \
		&& [[ "${RESULT}" = '/home/us' ]] \
		&& echo pass || echo fail





	if (($#))
	then
		echo "NCMP_STATE['completion_ignore_case']: ${NCMP_STATE['completion_ignore_case']}"
		echo "${NCMP_STATE[@]@K}"

		time ncmp_read_dir "${1}"
		nitems="${NCMP_CACHE[1]}"
		echo "${nitems} items"
		printf '  "%s"\n' "${NCMP_CACHE[@]}"

		while read line
		do
			ncmp_load_matches "${line}"
			for idx in "${NCMP_CACHE[@]:NCMP_CACHE_STATE+NCMP_CACHE[1]*3}"
			do
				echo "  ${idx}: ${NCMP_CACHE[idx]}"
			done

			ncmp_print_matches
		done
	fi
fi
