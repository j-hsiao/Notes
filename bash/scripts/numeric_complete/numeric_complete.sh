#!/bin/bash

# Numeric tab completion.
#
# Generally, I think the c-escape style is visually better, but isn't shell compatible.
# In that case, when tab completing, use c-escape.  When completing to a chosen/single
# value, then replace it with shell-compatible version.



# Default cache size
NCMP_CACHE_SIZE=${NCMP_CACHE_SIZE:-10}

. "${BASH_SOURCE[0]%numeric_complete.sh}shoptstack.sh"
. "${BASH_SOURCE[0]%numeric_complete.sh}chinfo.sh"
. "${BASH_SOURCE[0]%numeric_complete.sh}cache.sh"
ch_make NCMP_CACHE ${NCMP_CACHE_SIZE}

# Store internal state
declare -A NCMP_STATE

# The readline completion-ignore-case and show-mode-in-prompt
# settings are needed to determine numeric completion behavior.
# However, on Cygwin, bind is noticeably very slow.  A solution
# would be to cache the value of the settings into variables.

NCMP_STATE['completion_ignore_case']=
NCMP_STATE['show_mode_in_prompt']=
NCMP_STATE['editing_mode']=

ncmp_refresh_readline() {
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

ncmp_set_pager() # default pager and arguments
{
	# Determine if less is a suitable pager and set it.
	# Otherwise, use the default pager if given.
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
			return
		fi
	fi
	if (("${#}"))
	then
		NUMERIC_COMPLETE_pager=("${@}")
	fi
	return 1
}

ncmp_pathsplit() # <path> [dname_var=dname] [basename_var=bname]
# Parse <path> into dir name and base name.  The results
# are stored in the corresponding variables if provided.
# NOTE: dir1/dir2 will be split as dir1/ and dir2
#       dir1/dir2/ will be split as dir1/dir2/ and ''
{
	local -n ncmpps__dname="${2:-dname}" ncmpps__bname="${3:-bname}"
	[[ "${1}" =~ (.*/)?(.*) ]] # load into BASH_REMATCH
	ncmpps__dname="${BASH_REMATCH[1]}"
	ncmpps__bname="${BASH_REMATCH[2]}"
	if [[ "${ncmpps__dname:0:1}" != '/' ]]
	then
		ncmpps__dname="${PWD}/${ncmpps__dname}"
	fi
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
	# to shell-stype escaping
	ss_push extglob
	local ncmpe2s__tmp="${1//$'\e['*([0-9':;<=>?'])*([' !#$%&()*+,-."/'\'])[A-Za-z'@[\]^_\`~|{}']}"
	ss_pop
	ncmpe2s__tmp="${ncmpe2s__tmp//'\ '/ }"
	local -n ncmpe2s__out="${2:-RESULT}"
	# ${ncmpe2s__tmp@Q} always adds quotes regardless of whether they are necessary or not.
	# prefer printf -v in this case
	printf -v ncmpe2s__out '%q' "${ncmpe2s__tmp}"
}

ncmp_read_dir() # <dname>
{
	# Read and preprocess <dname> into the cache.
	# The cache (NCMP_CACHE) will contain:
	# 1. The current query
	# 2. The number of entries
	# 3. The display entries (maybe with colors, etc)
	# 4. the raw entries (no colors) for length + searching
	# 5. the display lengths.
	if ! ch_get NCMP_CACHE "${1}"
	then
		# NOTE: Tried implementing to find entries with a common prefix
		# but it was very slow, linear search much faster, tested up to
		# 1000 items.

		ss_push extglob globasciiranges
		NCMP_CACHE=()
		readarray -O2 -t NCMP_CACHE < <(ls -Apb --color=always "${1}" 2>/dev/null)
		# https://en.wikipedia.org/wiki/ANSI_escape_code
		# [0x30–0x3F]*  (0–9:;<=>?)
		# [0x20–0x2F]*  ( !"#$%&'()*+,-./)
		# 0x40–0x7E     (@A–Z[\]^_`a–z{|}~)
		NCMP_CACHE+=("${NCMP_CACHE[@]//$'\e['*(['0'-'?'])*(['!'-'/'])['@'-'~']}")
		NCMP_CACHE[1]="$((${#NCMP_CACHE[@]}/2))"
		ci_strdisplaylens NCMP_CACHE $((NCMP_CACHE[1]*2 + 2)) \
		"${NCMP_CACHE[@]:NCMP_CACHE[1]+2:NCMP_CACHE[1]}"
		ss_pop
	fi
}

ncmp_load_matches() # <query>
{
	# Load matches of <query> (index) into the end of NCMP_CACHE.
	# NCMP_CACHE[0] should be the last query if applicable.
	# <query> would be the new query.
	#
	# If readline completion-ignore-case is on, then if query is all
	# lower case, ignore case.  If query contains upper case, then
	# match case.  Otherwise, only match exact.

	# side note... This generally seems to be quite fast,
	# maybe refining previous match is not necessary?
	local out=$((NCMP_CACHE[1]*3 + 2))
	if [[ -z "${1}" ]]
	then
		local idx=$((NCMP_CACHE[1] + 1)) end=$((NCMP_CACHE[1]*2 + 2))
		while ((++idx < end))
		do
			NCMP_CACHE[out++]="${idx}"
		done
		return
	fi

	if [[ "${NCMP_STATE['completion_ignore_case']}" = 'on' && "${1,,}" = "${1}" ]]
	then
		local query="${1^^}"
		if [[ "${1#"${NCMP_CACHE[0]}"}" = "${1}" ]]
		then
			local idx=$((NCMP_CACHE[1] + 1)) end=$((NCMP_CACHE[1]*2 + 2)) candidate
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
			local idx=$((NCMP_CACHE[1] + 1)) end=$((NCMP_CACHE[1]*2 + 2))
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
	if (("${BASH_VERSINFO[0]:-3}" > 4 || ("${BASH_VERSINFO[0]:-3}" == 4 && "${BASH_VERSINFO[1]:-3}" >= 4)))
	then
		# \e[s saves position on screen, not in text buffer. If the
		# terminal is scrolled (ex. commandline at the bottom), then
		# the position becomes incorrect.  Thus, ensure the commandline
		# is not at the bottom by printing newlines to ensure no scrolling
		# will occurr (assuming the prompt is not going to exceed the
		# window height).  Using \b does not work because it does not wrap
		# up to the previous line.
		local numlines
		ncmp_count_lines "${PS1@P}${pre}${1}" '' numlines
		if ((numlines > 1))
		then
			printf "\\r${pre}${PS1@P}${1}\\e[$((numlines-1))A"
		fi
		printf "\\r${pre}${PS1@P}"
	else
		# don't know how to expand to prompt in this case...
		# so just use a basic $ 
		local numlines idx=0
		ncmp_count_lines "${1}" '' numlines
		while ((idx++<numlines)); do printf '\n'; done
		printf '\e[%sA\r%s$ ' "${pre}" "${numlines}"
	fi
	# printf "${1:0:${2}}"$'\e[s'"${1:${2}}"$'\e[u'
	# wiki says \e7 \e8 are more widely supported
	# than \e[s and \e[u
	printf "${1:0:${2}}"$'\e7'"${1:${2}}"$'\e8'
}



ncmp_cols_viable() # <strwidth_array> <numcols> <width>
{
	# Check that <numcols> columns of <strwidth_array>
	# can fit within <width>
	local -n ncmpcv__arr="${1}"
	local ncmpcv__ncols="${2}" ncmpcv__width="${3}"
	local fullrows=$((nitems / ${ncmpcv__ncols}))
	local remainder=$((nitems % ${ncmpcv__ncols}))
	local col=0 total=0
	local colwidths=()
	echo "nitems: ${nitems}"
	echo "remainder: ${nitems}"
	echo "full rows: ${fullrows}"
	while ((col < ${ncmpcv__ncols}))
	do
		local start=$((col*fullrows + col<remainder ? col : remainder))
		local stop=$((col*fullrows + col<remainder ? col : remainder))
		echo "col ${col}, ${start}:${stop}"
		ncmp_max "${1}" "${start}" "${stop}" colwidths[col]
		((total += colwidths[col++]))
	done
	echo "${colwidths[@]} ${total}"
	return $((total > ${ncmpcv__width}))
}
ncmp_calcshape() # <strwidth_array> [termwidth=${COLUMNS}] [minpad=1] [style='%d) ']
                 # [fullfmt] [lastfmt] [cols]
{
	# Calculate the table shape to display strings of the given lengths.
	# A single column has form:
	# [pre][padname][pad].  The last column does not need padding.
	# [pre]: The numbering for the entry is assumed to have the form 'N. '
	#        For simplicity, all [pre] sections have the same width.
	# [padname]: The right-padded name of the entry, up to the longest entry.
	# [pad]: The padding between columns.  This is at least <minpad>
	#
	# arguments:
	# 	<strwidth_array>: the array of string widths
	# 	[termwidth]: the maximum table width.
	# 	[minpad]: minimum padding between columns.
	# 	[style]: The numbering style, must contain '%d'
	# 	[fullfmt]: The output variable for a full row printf format.
	# 	[lastfmt]: The output variable for the last row printf format.
	# 	[cols]: The number of columns of the table.

	# minimum columns = 1
	# maximum columns = every column is min width
	# NOTE: it IS possible for fewer columns to be non-viable
	# ex:
	# total width = 80, pad 0
	# 2 columns net width 90    3 columns: net width 55
	#     5     45                  5     45      5
	#     5     5                   5     45      5
	#     5     5                   5     5
	#     45    5
	# In that case, maybe just go from max number of columns downwards?

	local -n ncmpcs__arr="${1}"
	local choices="${#ncmpcs__arr[@]}" termwidth="${2:-${COLUMNS}}" minpad="${3:-1}" prefmt="${4:-%d) }"
	prefmt="${prefmt/\%d/%${#choices}d}"

	local prelen
	printf -v prelen "${prefmt}" "${choices}"
	prelen="${#prelen}"

	local shortest
	ncmp_min "${1}" '' '' shortest

	local maxcols="$((termwidth / shortest + (termwidth%shortest ? 1 : 0)))"
	while ((maxcols*shortest + maxcols*prelen + (maxcols-1)*minpad > termwidth))
	do
		((--maxcols))
	done

	# TODO decrement to the first viable number of columns
}

ncmp_print_table() #
{
	:
	# TODO
}

ncmp_display_choices() #
{
	if [[ -z "${COLUMNS}" ]]
	then
		local COLUMNS=$(tput cols)
	fi
	# TODO
}



if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo 'Testing splitpath().'
	splitpath_testcases=( \
		'/:/:' \
		'/bin:/:bin' \
		"hello/world:${PWD}/hello/:world" \
		"hello/world/:${PWD}/hello/world/:" \
		"basename:${PWD}/:basename" \
		"/dev/shm:/dev/:shm" \
		"/dev/shm/:/dev/shm/:" \
		":${PWD}/:"\
	)

	for testcase in "${splitpath_testcases[@]}"
	do
		ncmp_pathsplit "${testcase%%:*}"
		[[ "${dname}:${bname}" = "${testcase#*:}" ]] && echo pass || printf 'fail\n\tgot : "%s"\n\twant: "%s"\n' "${dname}:${bname}" "${testcase#*:}"
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

	strlens=(2 2 2 10 10 2 2 2 2 2 2)
	echo "Testing cols_viable"
	ncmp_cols_viable strlens 3 22 && echo pass || echo "fail"
	ncmp_cols_viable strlens 3 21 && echo fail || echo pass

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
			for idx in "${NCMP_CACHE[@]:2+NCMP_CACHE[1]*3}"
			do
				echo "  ${idx}: ${NCMP_CACHE[idx]}"
			done
		done
	fi
fi
