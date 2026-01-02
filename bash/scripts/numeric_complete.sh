#!/bin/bash
# Settings:
# 	NUMERIC_COMPLETE_color
# 	  ls --color=* value.  Default to never (color can affect
# 	  performance, especially in network file)
## sidenote: observation
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
# 		"a string ${param[tab]}
# 		${2} = a string ${param  (without the })
# 		word = "a string ${param}
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
# 		ex: hello${HO[tab]} fails to do any completions with compgen

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && declare -Fp ncmp_run &>/dev/null && (($# == 0)) && return

. "${BASH_SOURCE[0]%"${BASH_SOURCE[0]##*/}"}util/restore_rematch.sh"
. "${BASH_SOURCE[0]%"${BASH_SOURCE[0]##*/}"}util/shoptstack.sh"
. "${BASH_SOURCE[0]%"${BASH_SOURCE[0]##*/}"}util/chinfo.sh"
. "${BASH_SOURCE[0]%"${BASH_SOURCE[0]##*/}"}util/cache.sh"
. "${BASH_SOURCE[0]%"${BASH_SOURCE[0]##*/}"}util/shparse.sh"

# Default cache size
NCMP_CACHE_SIZE=${NCMP_CACHE_SIZE:-10}
ch_make NCMP_CACHE ${NCMP_CACHE_SIZE}


# Store internal state
declare -gA NCMP_STATE

ncmp_refresh_readline() {
	# Refresh cached readline settings.
	# This is mostly to improve performance on cygwin.
	local st opt val
	while read -r st opt val
	do
		NCMP_STATE["${opt}"]="${val}"
	done < <(command bind -v 2>/dev/null)
}
ncmp_refresh_readline

# Should I even bother with this?
# it seems like this is never actually used...
if ! declare -f ncmp_orig_bind &>/dev/null
then
	case "$(type -t bind)" in
		file|builtin)
			ncmp_orig_bind() {
				command bind "${@}"
			}
			;;
		function)
			
			if [[ "$(declare -f bind)" = *'ncmp_orig_bind ' ]]
			then
				printf 'Warning, experimental overriding function bind.\n'
				eval ncmp_orig_"$(declare -f bind)"
			else
				printf 'bind is a function that already references ncmp_orig_bind\n'
			fi
			;;
		alias)
			printf 'Warning, experimental overriding alias bind.\n'
			ncmp_bind_alias=$(alias bind)
			unalias bind
			eval ncmp_bind_alias=${ncmp_bind_alias#*=}
			if [[ "$(type -t bind)" = 'function' ]]
			then
				eval ncmp_orig2_"$(declare -f bind)"
				eval $'ncmp_orig_bind() {\n'"${ncmp_bind_alias/#bind/ncmp_orig2_bind}"$'\n}'
			else
				eval $'ncmp_orig_bind() {\n'"${ncmp_bind_alias/#bind/command bind}"$'\n}'
			fi
			unset ncmp_bind_alias
			;;
		*)
			printf 'Warning, overriding unknown bind implementation.'
			ncmp_orig_bind() { command bind "${@}"; }
			;;
	esac
	bind() {
		trap ncmp_refresh_readline RETURN
		ncmp_orig_bind "${@}"
	}
fi
ncmp_run()
{
	# Set up useful variables but put in function to reduce polluting environment with many variables.
	# all ncmp functions expect to be called under ncmp_run and so expect these variables
	# to be available
	local NCMP_CACHE_PREFIX=0
	local NCMP_QUERY=$((NCMP_CACHE_PREFIX++))
	local NCMP_COUNT=$((NCMP_CACHE_PREFIX++))
	local NCMP_ITEMS='NCMP_CACHE[NCMP_COUNT]'
	local -n NCMP_DNAME=NCMP_CACHE_index
	local NCMP_CHOICE='NCMP_CACHE_PREFIX' # choices, may contain ansi colors
	local NCMP_LENGTH='NCMP_CACHE_PREFIX + NCMP_ITEMS' # display lengths
	local NCMP_REFINE='NCMP_CACHE_PREFIX + NCMP_ITEMS*2' # chosen indices

	local BIND_SHOW_MODE_IN_PROMPT='show-mode-in-prompt'
	local BIND_EDITING_MODE='editing-mode'
	local BIND_COMPLETION_IGNORE_CASE='completion-ignore-case'

	# NOTE: ansi code pattern requires extglob and globasciiranges
	# https://en.wikipedia.org/wiki/ANSI_escape_code
	# *([0-?])*([ -/])[@-~]
	local NCMP_ANSI_CODE_PATTERN=$'\e\\[*([\x30-\x3f])*([\x20-\x2f])[\x40-\x7e]'

	local NCMP_ANSI_COLUMN_FORMAT='\\e[%dG'
	if [[ "${TERM}" = *color* || "${COLORTERM}" = *color* ]]
	then
		local ANSI_BLUE=$'\e[01;34m'
		local ANSI_RESET=$'\e[0m'
		local ANSI_NUMBER=$'\e[30;47m'
	else
		local ANSI_BLUE=
		local ANSI_RESET=
		local ANSI_NUMBER=
	fi
	"${@}"
}

ncmp_pathsplit() # <path> [dname_var=dname] [basename_var=bname] [fulldir=dpath]
# Parse <path> into dir name and base name and full normalized dir name.
# The results are stored in the corresponding variables if provided.
# NOTE: dir1/dir2 will be split as dir1/ and dir2
#       dir1/dir2/ will be split as dir1/dir2/ and ''
{
	local -n ncmpps__dname="${2:-dname}" ncmpps__bname="${3:-bname}" ncmpps__dpath="${4:-dpath}"
	local ncmpps__orig_rematch=("${BASH_REMATCH[@]}")
	[[ "${1}" =~ (.*/)?(.*) ]]
	ncmpps__dname="${BASH_REMATCH[1]}"
	ncmpps__bname="${BASH_REMATCH[2]}"
	restore_BASH_REMATCH ncmpps__orig_rematch
	ss_push extglob
	ncmpps__dpath="${ncmpps__dname//+(\/)/\/}"
	ncmpps__dpath="${ncmpps__dpath/#~*([^\/])/${HOME}}"
	ss_pop
	if [[ "${ncmpps__dpath:0:1}" != '/' ]]
	then
		ncmpps__dpath="${PWD}/${ncmpps__dpath}"
	fi
}

ncmp_expand_prompt() # [prompt=${PS1}] [out=]
{
	# Expand prompt as a prompt string.  If out is provided, then store
	# the result to out.  Otherwise, print the result.
	local ncmpep__prompt="${1:-"${PS1}"}"
	if (("${BASH_VERSINFO[0]:-3}" > 4 || ("${BASH_VERSINFO[0]:-3}" == 4 && "${BASH_VERSINFO[1]:-3}" >= 4)))
	then
		printf ${2:+-v "${2}"} '%s' "${ncmpep__prompt@P}"
		return
	fi

	local ncmpep__parts=()
	local ncmpep__idx=0
	local ncmpep__orig_rematch=("${BASH_REMATCH[@]}")
	trap 'restore_BASH_REMATCH ncmpep__orig_rematch; trap - RETURN' RETURN
	while [[ "${ncmpep__prompt:ncmpep__idx}" =~ ^(("\$'"|[^'$\'])*)(['$\'])? ]]
	do
		if (("${#BASH_REMATCH[1]}"))
		then
			ncmpep__parts+=("${BASH_REMATCH[1]}")
			((ncmpep__idx+="${#BASH_REMATCH[1]}"))
		fi
		if (("${#BASH_REMATCH[-1]}"))
		then
			case "${BASH_REMATCH[-1]}" in
				'$')
					local beg end part
					shparse_parse_dollar "${ncmpep__prompt}" 'ncmpep__parts[${#ncmpep__parts[@]}]' beg end "${ncmpep__idx}"
					if ((end < 0))
					then
						ncmpep__parts+=("${ncmpep__prompt:ncmpep__idx}")
						ncmpep__idx="${#ncmpep__prompt}"
					else
						ncmpep__idx="${end}"
					fi
					;;
				'\')
					case "${ncmpep__prompt:ncmpep__idx:2}" in
						\\[aenr]) printf -v "ncmpep__parts[${#ncmpep__parts[@]}]" "${ncmpep__prompt:ncmpep__idx:2}";;
						'\d') ncmpep__parts+=("$(date '+%a %b %d')");;
						'\h') ncmpep__parts+=("${HOSTNAME%%.*}");;
						'\H') ncmpep__parts+=("${HOSTNAME}");;
						'\j') ncmpep__parts+=("$(jobs|wc-l)");;
						'\l') ncmpep__parts+=("$(tty)"); ncmpep__parts[-1]="${ncmpep__parts[-1]##*/}";;
						'\s') ncmpep__parts+=("${SHELL##*/}");;
						'\t') ncmpep__parts+=("$(date '+%H:%M:%S')");;
						'\T') ncmpep__parts+=("$(date '+%I:%M:%S')");;
						'\@') ncmpep__parts+=("$(date '+%I:%M %p')");;
						'\A') ncmpep__parts+=("$(date '+%H:%M')");;
						'\u') ncmpep__parts+=("${USER}");;
						'\v') ncmpep__parts+=("${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}");;
						'\V') ncmpep__parts+=("${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}");;
						'\w') ncmpep__parts+=("${PWD/#"${HOME}"/"${PROMPT_DIRTRIM:-"~"}"}");;
						'\W')
							if [[ "${PWD}" = "${HOME}" ]]
							then
								ncmpep__parts+=('~')
							else
								ncmpep__parts+=("${PWD##*/}")
							fi
							;;
						'\!') ncmpep__parts+=("${HISTCMD}");;
						'\#')
							# TODO: the command number number of this command
							# doesn't seem to be any way to get this, but ti
							# also doesn't seem all that useful either...
							;;
						'\$')
							if ((UID == 0))
							then
								ncmpep__parts+=('#')
							else
								ncmpep__parts+=('$')
							fi
							;;
						'\\') ncmpep__parts+=('\');;
						'\['*|'\]'*) ;;
						*)
							if [[ "${ncmpep__prompt:ncmpep__idx}" =~ ^$'\\D\x7b'([^$'\x7d']*)($'\x7d'|$) ]]
							then
								ncmpep__parts+=("$(date "+${BASH_REMATCH[1]}")")
								ncmpep__idx+="${#BASH_REMATCH[0]}"
							elif [[ "${ncmpep__prompt:ncmpep__idx}" =~ ^'\'[0-7]($|[0-7]($|[0-7])) ]]
							then
								printf -v "ncmpep__parts[${#ncmpep__parts[@]}]" "${BASH_REMATCH[0]}"
								((ncmpep__idx += "${#BASH_REMATCH[0]}"))
							else
								ncmpep__parts+=('\')
								((++ncmpep__idx))
							fi
							continue
							;;
					esac
					((ncmpep__idx += 2))
					;;
			esac
		else
			printf ${2:+-v "${2}"} '%s' "${ncmpep__parts[@]}"
			return
		fi
	done
}

ncmp_count_lines() # <text> [width=${COLUMNS}] [out=RESULT]
{
	# Count the number of lines <text> would occupy in a terminal of <width>.
	local ncmpcl__text="${1}" ncmpcl__width="${2:-${COLUMNS}}"
	local -n ncmpcl__out="${3:-RESULT}"
	ncmpcl__out=1
	local ncmpcl__col=0 ncmpcl__idx ncmpcl__clen
	local ncmpcl__textlen="${#ncmpcl__text}"
	for ((ncmpcl__idx=0; ncmpcl__idx < ncmpcl__textlen; ++ncmpcl__idx))
	do
		local ncmpcl__chara="${ncmpcl__text:ncmpcl__idx:1}"
		if [[ "${ncmpcl__chara}" = $'\n' ]]
		then
			((ncmpcl__col=0, ++ncmpcl__out))
		elif [[ "${ncmpcl__chara}" = $'\r' ]]
		then
			((ncmpcl__col=0))
		else
			ci_charwidth "${ncmpcl__chara}" ncmpcl__clen
			((ncmpcl__col + ncmpcl__clen <= ncmpcl__width ? (ncmpcl__col+=ncmpcl__clen) : (ncmpcl__col=ncmpcl__clen, ++ncmpcl__out)))
		fi
	done
}
ncmp_mimic_prompt() # <command> <pos>
{
	# Mimic the bash prompt.
	# Leave the cursor at position <pos> of <command>
	# This is necessary so that the choices can be displayed and the cursor
	# ends up in an appropriate position to continue typing the command.
	local pre=
	if [[ "${NCMP_STATE['show-mode-in-prompt']}" = 'on' ]]
	then
		if [[ "${NCMP_STATE['editing-mode']}" = 'emacs' ]]
		then
			pre+='@'
		else
			pre+='(ins)'
		fi
	fi
	# @P operator requires bash 4.4+
	local prompt rawprompt prompt_nonprinting='\\\[*(@([^\\]|\\[^\'$'\x5d'']))\\\]'
	ncmp_expand_prompt "${PS1}" prompt
	ncmp_expand_prompt "${PS1//@(${prompt_nonprinting}|${NCMP_ANSI_CODE_PATTERN})}" rawprompt
	# Cursor position is saved as position in screen, not buffer.  If printing
	# would cause scrolling, then the position will be wrong.
	prompt="${prompt%"${prompt##*$'\n'}"}${pre}${prompt##*$'\n'}"
	rawprompt="${rawprompt%"${rawprompt##*$'\n'}"}${pre}${rawprompt##*$'\n'}"
	local numlines
	ncmp_count_lines "${rawprompt}${1}" '' numlines
	if ((--numlines > 0))
	then
		printf '\r%s\e[%dA' "${prompt}${1}" "${numlines}"
	fi
	printf '\r%s' "${prompt}"

	# printf "${1:0:${2}}"$'\e[s'"${1:${2}}"$'\e[u'
	# wiki says \e7 \e8 are more widely supported
	# than \e[s and \e[u
	printf "${1:0:${2}}"$'\e7'"${1:${2}}"$'\e8'
}

ncmp_escape2shell() # <text> [out=RESULT]
{
	# Convert <text> from ls -b style escaping to shell-style escaping
	local -n ncmpe2s__out="${2:-RESULT}"
	printf -v ncmpe2s__out "${1//'\ '/ }"
	# ${ncmpe2s__tmp@Q} always adds quotes regardless of whether they are necessary or not.
	# prefer printf -v in this case
	printf -v ncmpe2s__out '%q' "${ncmpe2s__out}"
}

ncmp_read_dir() # <dname> [force=]
{
	# Load directory entries into NCMP_CACHE.
	# If [force] is not empty, then force re-reading the
	# directory.  This is useful if there was some change
	# to a directory and the cache is outdated.
	if ! ch_get NCMP_CACHE "${1}" || [[ -n "${2}" ]]
	then
		# Sidenote, using compgen can be very very slow...
		# ls = 0.18 seconds, but compgen = 3 seconds if compgen -df -o plusdirs (to distinguish directories)
		# or compgen -df 2 seconds
		# find path -printf '%y %f' can also be much slower than ls -Apb.
		# If this is the case, ls seems to be way more preferrable to compgen
		# but compgen does give some benefits like no need to implement
		# parsing partial bash/readline parsing.

		NCMP_CACHE=()
		readarray -O${NCMP_CACHE_PREFIX} -t NCMP_CACHE \
			< <(ls -Apb --color="${NUMERIC_COMPLETE_color:-never}" "${1}" 2>/dev/null)
		# https://en.wikipedia.org/wiki/ANSI_escape_code
		# [0x30–0x3F]*  (0–9:;<=>?)
		# [0x20–0x2F]*  ( !"#$%&'()*+,-./)
		# 0x40–0x7E     (@A–Z[\]^_`a–z{|}~)
		if [[ "${NUMERIC_COMPLETE_color:-never}" = 'always' ]]
		then
			ss_push extglob globasciiranges
			local raw=("${NCMP_CACHE[@]//${NCMP_ANSI_CODE_PATTERN}}")
			ss_pop
			NCMP_CACHE[NCMP_COUNT]="${#NCMP_CACHE[@]}"
			ci_strdisplaylens NCMP_CACHE "$((NCMP_LENGTH))" "${raw[@]}"
		else
			NCMP_CACHE[NCMP_COUNT]="${#NCMP_CACHE[@]}"
			ci_strdisplaylens NCMP_CACHE "$((NCMP_LENGTH))" "${NCMP_CACHE[@]:NCMP_CHOICE:NCMP_ITEMS}"
			local i
			for ((i=NCMP_CHOICE; i<NCMP_LENGTH; ++i))
			do
				if [[ "${NCMP_CACHE[i]: -1}" = '/' ]]
				then
					NCMP_CACHE[i]="${ANSI_RESET}${ANSI_BLUE}${NCMP_CACHE[i]%/}${ANSI_RESET}/"
				fi
			done
		fi
	fi
}

ncmp_load_matches() # <query>
{
	# Load indices matching <query> [0-NCMP_ITEMS) into the refine segment of NCMP_CACHE.
	# If readline completion-ignore-case and <query> is lowercase, then ignorecase.
	local idx out=$((NCMP_REFINE))
	NCMP_CACHE[NCMP_QUERY]="${1}"
	if [[ -z "${1}" ]]
	then
		for ((idx=0; idx<NCMP_ITEMS; ++idx))
		do
			NCMP_CACHE[out++]=${idx}
		done
	else
		# From testing, performance doesn't seem to be an issue passing through all
		# choices instead of only refined choices.  The code is much simpler like this
		ss_push extglob globasciiranges
		if [[ ${NCMP_STATE[$BIND_COMPLETION_IGNORE_CASE],,} = 'on' && "${1}" = "${1,,}" ]]
		then
			for ((idx=0; idx<NCMP_ITEMS; ++idx))
			do
				local raw="${NCMP_CACHE[idx+NCMP_CHOICE]//${NCMP_ANSI_CODE_PATTERN}}"
				if [[ "${raw,,}" = "${1}"* ]]
				then
					NCMP_CACHE[out++]="${idx}"
				fi
			done
		else
			for ((idx=0; idx<NCMP_ITEMS; ++idx))
			do
				if [[ "${NCMP_CACHE[idx+NCMP_CHOICE]//${NCMP_ANSI_CODE_PATTERN}}" = "${1}"* ]]
				then
					NCMP_CACHE[out++]="${idx}"
				fi
			done
		fi
		ss_pop
	fi
	for ((idx=${#NCMP_CACHE[@]}-1; idx >= out; --idx))
	do
		unset NCMP_CACHE[idx]
	done
}

ncmp_reduce() # <op> <int_array_name> [start=0] [stop=end] [output=RESULT]
{
	# Reduce the input array with the given operation.
	# If the range is empty, then output will be empty.
	local ncmprd__op="${1}"
	local -n ncmprd__array="${2}"
	local -n ncmprd__output="${5:-RESULT}"
	local ncmprd__start=$(("${3:-0}"))
	local ncmprd__stop="${#ncmprd__array[@]}"
	((ncmprd__stop = ncmprd__stop <= ${4:-ncmprd__stop} ? ncmprd__stop : ${4:-ncmprd__stop}))
	if (("${ncmprd__start}" >= "${ncmprd__stop}"))
	then
		ncmprd__output=
		return
	fi
	ncmprd__output="${ncmprd__array[ncmprd__start]}"
	while ((++ncmprd__start < ncmprd__stop))
	do
		if ((ncmprd__array[ncmprd__start] ${ncmprd__op} ncmprd__output))
		then
			ncmprd__output="${ncmprd__array[ncmprd__start]}"
		fi
	done
}

ncmp_cols_viable() # <strwidth_array> <numcols> <width> [colwidths=RESULT]
{
	# Calculate column widths of <numcols> columns if within <width>.
	# <strwidth_array>: the array containing widths of strings
	# <numcols>: The number of columns.
	# <width>: The target display width.
	# [colwidths]: The output array name, defaults to RESULT.
	local -n ncmpcv__arr="${1}"
	local -n ncmpcv__colwidths="${4:-RESULT}"
	local ncmpcv__cols="${2}"

	local ncmpcv__remainder=$((${#ncmpcv__arr[@]} % ncmpcv__cols))
	local ncmpcv__rows=$((${#ncmpcv__arr[@]} / ncmpcv__cols))
	if ((ncmpcv__remainder && ncmpcv__remainder + ncmpcv__rows < ncmpcv__cols))
	then
		return 1
	fi

	((ncmpcv__rows += (ncmpcv__remainder > 0)))
	local ncmpcv__col=0
	ncmpcv__colwidths=()
	for ((ncmpcv__col=0; ncmpcv__col < ncmpcv__cols; ++ncmpcv__col))
	do
		ncmp_reduce '>' "${1}" "$((ncmpcv__col * ncmpcv__rows))" "$(((ncmpcv__col+1) * ncmpcv__rows))" 'ncmpcv__colwidths[ncmpcv__col]'
	done
	((${ncmpcv__colwidths[@]/%/+}0 <= "${3}"))
}
ncmp_calcfmt() # <strwidth_array> [termwidth=${COLUMNS}] [minpad=1]
               # [style="${ANSI_RESET}${ANSI_NUMBER}%d.${ANSI_RESET}"] [fmt=fmt]
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

	local -n ncmpcf__arr="${1}"
	local -n ncmpcf__fmt="${5:-fmt}"
	local ncmpcf__nchoices="${#ncmpcf__arr[@]}"
	local ncmpcf__termwidth="${2:-${COLUMNS:-$(tput cols)}}"
	local ncmpcf__minpad="${3:-1}"
	((ncmpcf__termwidth += ncmpcf__minpad))
	local ncmpcf__numfmt="${4:-"${ANSI_RESET/$'\e'/'\e'}${ANSI_NUMBER/$'\e'/'\e'}%d.${ANSI_RESET/$'\e'/'\e'} "}"
	if ((!ncmpcf__nchoices)); then ncmpcf__fmt=(); return; fi
	ncmpcf__numfmt="${ncmpcf__numfmt/'%d'/"%${#ncmpcf__nchoices}d"}"

	local ncmpcf__numlen
	printf -v ncmpcf__numlen "${ncmpcf__numfmt}" "${ncmpcf__nchoices}"
	ss_push extglob globasciiranges
	ncmpcf__numlen="${ncmpcf__numlen//${NCMP_ANSI_CODE_PATTERN}}"
	ss_pop
	ci_strdisplaylen "${ncmpcf__numlen}" ncmpcf__numlen
	local ncmpcf__ncols
	ncmp_reduce '<' "${1}" '' '' ncmpcf__ncols
	ncmpcf__ncols=$((ncmpcf__termwidth / (ncmpcf__ncols + ncmpcf__numlen + ncmpcf__minpad)))
	ncmpcf__ncols=$((ncmpcf__ncols > ncmpcf__nchoices ? ncmpcf__nchoices : ncmpcf__ncols))
	local ncmpcf__colwidths=()
	while ((ncmpcf__ncols > 1)) && ! ncmp_cols_viable "${1}" "${ncmpcf__ncols}" \
		$((ncmpcf__termwidth - ncmpcf__ncols*(ncmpcf__numlen+ncmpcf__minpad))) ncmpcf__colwidths
	do
		((--ncmpcf__ncols))
	done

	if ((ncmpcf__ncols <= 1))
	then
		ncmpcf__fmt=('\r'"${ncmpcf__numfmt}"'%s\n')
	else
		ncmpcf__fmt=()
		local ncmpcf__idx=0
		local ncmpcf__colstart=1
		for ((ncmpcf__idx=0; ncmpcf__idx<ncmpcf__ncols; ++ncmpcf__idx))
		do
			printf -v ncmpcf__fmt[ncmpcf__idx] "${NCMP_ANSI_COLUMN_FORMAT}"'%s%%s' \
				"${ncmpcf__colstart}" "${ncmpcf__numfmt}"
			((ncmpcf__colstart+=ncmpcf__numlen + ncmpcf__colwidths[ncmpcf__idx] + ncmpcf__minpad))
		done
	fi
}

NCMP_CACHE_STATE=3
ncmp_print_matches() # [termwidth=${COLUMNS}] [minpad=1] [style='%d. ']
{
	# Print the currently loaded matches as a table (ansi required).
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
			ncmp_last_word "${1:1}" "${@:2}"
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

if [[ "${0}" != "${BASH_SOURCE[0]}" ]]
then
	if [[ "${-}" == *i* && "${1}" != 'nobind' ]]
	then
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
	fi
else
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
	ncmp_reduce '>' testarr
	(( ${RESULT} == 9 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '>' testarr 0 5
	(( ${RESULT} == 8 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '>' testarr 11 14
	(( ${RESULT} == 7 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '>' testarr 0 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '>' testarr 2 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"

	echo 'Testing min()'
	ncmp_reduce '<' testarr
	(( ${RESULT} == 0 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '<' testarr 0 5
	(( ${RESULT} == 1 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '<' testarr 11 14
	(( ${RESULT} == 3 )) && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '<' testarr 0 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"
	ncmp_reduce '<' testarr 2 0
	[[ "${RESULT}" == '' ]] && echo pass || echo "fail: ${RESULT}"

	echo 'Testing count_lines()'
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
	ncmp_cols_viable strlens 10 6000 && echo fail || echo pass

	# columns   colwidths       prelen  padding     total
	# 2         +10 +10         +4*2    +1          29
	# 3         +10 +10 +2      +4*3    +2          36
	# 4         +2 +10 +10 +2   +4*4    +3          43
	echo "Testing calcfmt"
	ncmp_run ncmp_calcfmt strlens 29 1 '' fmt && ((${#fmt[@]} == 2)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_run ncmp_calcfmt strlens 35 1 '' fmt && ((${#fmt[@]} == 2)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_run ncmp_calcfmt strlens 36 1 '' fmt && ((${#fmt[@]} == 3)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[31G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_run ncmp_calcfmt strlens 42 1 '' fmt && ((${#fmt[@]} == 3)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[16G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[31G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_run ncmp_calcfmt strlens 43 1 '' fmt && ((${#fmt[@]} == 4)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[8G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[23G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[3]}" = '\e[38G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_run ncmp_calcfmt strlens 1000 1 '' fmt && ((${#fmt[@]} == 11)) \
		&& [[ "${fmt[0]}" = '\e[1G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[1]}" = '\e[8G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[2]}" = '\e[15G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[3]}" = '\e[22G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[4]}" = '\e[37G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[5]}" = '\e[44G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[6]}" = '\e[51G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[7]}" = '\e[58G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[8]}" = '\e[73G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[9]}" = '\e[80G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& [[ "${fmt[10]}" = '\e[87G\e[0m\e[30;47m%2d.\e[0m %s' ]] \
		&& echo pass || echo fail

	ncmp_last_word '"this is a str and /home/us' \
		&& [[ "${RESULT}" = '/home/us' ]] \
		&& echo pass || echo fail





	if (($#))
	then
		echo "NCMP_STATE['completion-ignore-case']: ${NCMP_STATE['completion-ignore-case']}"
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
