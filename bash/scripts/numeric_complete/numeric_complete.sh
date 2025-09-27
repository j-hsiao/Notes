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
NCMP_STATE['cacheidx']=0

# The readline completion-ignore-case and show-mode-in-prompt
# settings are needed to determine numeric completion behavior.
# However, on Cygwin, bind is noticeably very slow.  A solution
# would be to cache the value of the settings into variables.

NCMP_STATE['completion_ignore_case']=
NCMP_STATE['show_mode_in_prompt']=
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
		local data="$(ncmp_orig_bind -v)"
		local tmp="${data#*completion-ignore-case }"
		NCMP_STATE['completion_ignore_case']="${tmp:0:2}"
		tmp="${data#*show-mode-in-prompt }"
		NCMP_STATE['show_mode_in_prompt']="${tmp:0:2}"
		return "${ret}"
	}
	if [[ "${0}" != "${BASH_SOURCE[0]}" ]]
	then
		bind
	fi
fi

ncmp_set_pager()
{
	# Set NUMERIC_COMPLETE_pager variable to use less if available.
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
	local stop="${3:-${#ncmpmx__array[@]}}"
	local start="${2:-0}"
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

ncmp_calcshape() # <strwidth_array> <start> <stop> <termwidth> <minpad>
                 # [nrows=rows] [ncols=cols] [prewidth=prewidth]
{
	# Calculate the table shape to display strings
	# of the given lengths from start to stop.
	# <strwidth_array>: the array of string widths
	# <start>: Starting index
	# <stop>: stopping index
	# <minpad>: minimum padding between columns
	:
}

ncmp_count_lines() # <text> <width> [out=RESULT]
{
	# Count the number of lines <text> would take in a terminal of <width>.
	local ncmpcl__text="${1}" ncmpcl__width="${2}"
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

ncmp_mimic_prompt() # <width>
{
	# Mimic the bash prompt $PS1 and any existing command.
	:
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
	# The display uses shell-escape for quoting
	# so typing matches the display.
	if ! ch_get NCMP_CACHE "${1}"
	then
		# NOTE: Tried implementing a trie in bash, very slow
		# just iterate linearly much faster, at least for 1000 items

		# Cache requirements:
		# 1. the query
		# 2. the names
		# 	a. the display name: the name to be displayed, may include colors, etc
		# 	b. the raw name: Because with/without colors compare different due to
		# 	                 escape code bytes.
		# 3. the display length, with 1000 items of decent size, can take about half a second
		#    to calculate all the lengths so maybe should cache this too...
		# chosen structure:
		# (query total name... rawname... length...)

		ss_push extglob
		NCMP_CACHE=()
		readarray -O2 -t NCMP_CACHE < <(ls -Apb --color=always "${1}" 2>/dev/null)

		# https://en.wikipedia.org/wiki/ANSI_escape_code
		# [0x30–0x3F]*  (0–9:;<=>?)
		# [0x20–0x2F]*  ( !"#$%&'()*+,-./)
		# 0x40–0x7E     (@A–Z[\]^_`a–z{|}~)

		# TODO: removal fails on bash 4.4
		NCMP_CACHE+=("${NCMP_CACHE[@]//$'\e['*(['0'-'?'])*(['!'-'/'])['@'-'~']}")
		NCMP_CACHE[1]="$((${#NCMP_CACHE[@]}/2))"
		ci_strdisplaylens NCMP_CACHE $((NCMP_CACHE[1]*2 + 2)) \
		"${NCMP_CACHE[@]:NCMP_CACHE[1]+2:NCMP_CACHE[1]}"
		ss_pop
	fi
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

	echo 'Testing cout_lines()'
	ncmp_count_lines hello 11
	((${RESULT} == 1)) && echo pass || echo "fail: ${RESULT} vs 1"
	ncmp_count_lines hello\ world 11
	((${RESULT} == 1)) && echo pass || echo "fail: ${RESULT} vs 1"
	ncmp_count_lines hello\ world 10
	((${RESULT} == 2)) && echo pass || echo "fail: ${RESULT} vs 1"
	ncmp_count_lines hello\ w$'\n'orld 10
	((${RESULT} == 2)) && echo pass || echo "fail: ${RESULT} vs 1"

	if (($#))
	then
		ncmp_read_dir .
	fi
fi
