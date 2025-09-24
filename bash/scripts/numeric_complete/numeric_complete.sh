#!/bin/bash

# Numeric tab completion.
# Internal state is stored in the NCMP_STATE associative array environment variable.
# This allows state to be saved between function calls (For example, caching the
# result of listing a directory).

declare -A NCMP_STATE

# The readline completion-ignore-case and show-mode-in-prompt
# settings are needed to determine numeric completion behavior.
# However, on Cygwin, bind is noticeably very slow.  A solution
# would be to cache the value of the settings into variables.

NCMP_STATE['completion_ignore_case']=
NCMP_STATE['show_mode_in_prompt']=
if ! declare -f NCMP_orig_bind &>/dev/null
then
	case "$(type -t bind)" in 
		file|builtin)
			NCMP_orig_bind() {
				command bind "${@}"
			}
			;;
		function)
			if [[ ! "$(declare -f bind)" =~ .*'NCMP_orig_bind ' ]]
			then
				printf 'Warning, experimental overriding function bind.\n'
				eval NCMP_orig_"$(declare -f bind)"
			else
				printf 'bind is a function that already references NCMP_orig_bind\n'
			fi
			;;
		alias)
			printf 'Warning, experimental overriding alias bind.\n'
			NCMP_STATE['bind_alias']=$(alias bind)
			NCMP_orig_bind() {
				alias bind="${NCMP_STATE['bind_alias']}"
				bind
				unalias bind
			}
			unalias bind
			;;
		*)
			printf 'Warning, overriding unknown bind implementation.'
			NCMP_orig_bind() { command bind "${@}"; }
			;;
	esac
	bind() {
		NCMP_orig_bind "${@}"
		local ret=$?
		local data="$(NCMP_orig_bind -v)"
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

NUMERIC_COMPLETE_set_pager()
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

NCMP_pathsplit() # <path> [dname_var=dname] [basename_var=bname]
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

NCMP_max() # <int_array_name> [start=0] [stop=end] [output=RESULT]
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

NCMP_calcshape() # <strwidth_array> <start> <stop> <termwidth> <minpad>
                 # [nrows=rows] [ncols=cols] [prewidth=prewidth]
{
	# Calculate the table shape to display strings
	# of the given lengths from start to stop.
	# <strwidth_array>: the array of string widths
	# <start>: Starting index
	# <stop>: stopping index
	# <minpad>: minimum padding between columns
}



if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo Testing numeric_complete
	splitpath_testcases=( \
		'/:/:' \
		"hello/world:${PWD}/hello/:world" \
		"hello/world/:${PWD}/hello/world/:" \
		"basename:${PWD}/:basename" \
		"/dev/shm:/dev/:shm" \
		"/dev/shm/:/dev/shm/:" \
	)

	for testcase in "${splitpath_testcases[@]}"
	do
		NCMP_pathsplit "${testcase%%:*}" dname bname
		[[ "${dname}:${bname}" = "${testcase#*:}" ]] && echo pass || printf 'fail\n\tgot : "%s"\n\twant: "%s"\n' "${dname}:${bname}" "${testcase#*:}"
	done

	testarr=(6 5 1 2 8 9 7 6 1 2 9 3 5 7 1 2 9 8 4 1 8 3 4 5 4 3 6 7 1 0 2 3 4 0 9 1 2 3 4)
	NCMP_max testarr
	(( ${RESULT} == 9 )) && echo pass || echo "fail: ${RESULT}"

fi
