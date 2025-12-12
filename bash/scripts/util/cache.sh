#!/bin/bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && declare -Fp ch_make &>/dev/null && (($# == 0)) && return

ch_make() # <name> [size=10]
{
	# Create a cache.
	# The cache consists of a set of variables:
	# 1. nameref: This points to the corresponding chosen cache entry
	#             and matches <name> This will be changed to point to
	#             the corresponding cache entry.
	# 2. index: This is an array of alternating key and varname.
	#           It is just <name> with _index appended to the end.
	#           The varname is the name of the actual variable that
	#           represents the value for the corresponding key.
	declare -gn "${1}"="${1}0"
	local -n chmk__arr="${1}_index"
	chmk__arr=()
	local idx=0
	while ((idx < ${2:-10}))
	do
		chmk__arr[idx*2]=""
		chmk__arr[idx*2 + 1]="${1}${idx}"
		((++idx))
	done
}

ch_key() # <name> [out=RESULT]
{
	# Return the current key for the cache.
	local -n chgt__arr="${1}_index"
	eval "${2:-RESULT}="'"${chgt__arr[0]}"'
}

ch_get() # <name> <key> [out]
{
	# Point <name> to the corresponding cache entry.
	# <name> is the name-reference variable created from ch_make.
	# if [out] is provided, then set it to the actual variable name.
	# If it does not exist, create a new one, possibly invalidating
	# the oldest entry.  If found, then return code 0
	# If new, then return code 1.
	# NOTE: the new entry might or might not have old data.
	# Check the return code to know if it should be reinitialized or not.
	local -n chgt__arr="${1}_index"
	local idx=-2
	while (((idx+=2) < ${#chgt__arr[@]}))
	do
		if [[ "${chgt__arr[idx]}" = "${2}" ]]
		then
			local pick="${chgt__arr[++idx]}"
			while ((idx >= 2))
			do
				chgt__arr[idx]="${chgt__arr[idx-2]}"
				((--idx))
			done
			chgt__arr[0]="${2}"
			chgt__arr[1]="${pick}"
			declare -gn "${1}"="${pick}"
			return 0
		fi
	done
	chgt__arr=("${2}" "${chgt__arr[-1]}" "${chgt__arr[@]:0:idx-2}")
	declare -gn "${1}=${chgt__arr[1]}"
	if [[ -n "${3}" ]]
	then
		local -n chgt__truname="${3}"
		chgt__truname="${chgt__arr[1]}"
	fi
	return 1
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo "Testing cache."
	echo "Make Cache."
	ch_make mycache 3
	((${#mycache_index[@]} == 6)) && echo pass || echo fail
	((${#mycache[@]} == 0)) && echo pass || echo fail

	echo "Testing create new entry."
	! ch_get mycache key1 && echo pass || echo fail
	mycache=(1 2 3)
	! ch_get mycache key2 && echo pass || echo fail
	mycache=(4 5 6 7)

	echo "Retrieve existing entry."
	ch_get mycache key1 && echo pass || echo fail
	((${#mycache[@]} == 3)) && echo pass || echo fail

	echo "Create new entry"
	! ch_get mycache key3 && echo pass || echo fail
	mycache=(8 9 10 11 12)


	echo "Retrieve existing entries."
	ch_get mycache key1 && echo pass || echo fail
	((${#mycache[@]} == 3)) && [[ "${mycache[@]}" = '1 2 3' ]] && echo pass || echo fail

	ch_get mycache key3 && echo pass || echo fail
	((${#mycache[@]} == 5)) && [[ "${mycache[@]}" = '8 9 10 11 12' ]] && echo pass || echo fail

	ch_get mycache key2 && echo pass || echo fail
	((${#mycache[@]} == 4)) && [[ "${mycache[@]}" = '4 5 6 7' ]] && echo pass || echo fail

	echo "Invalidate oldest entry."

	! ch_get mycache key4 && echo pass || echo fail

	ch_get mycache key3 && echo pass || echo fail
	((${#mycache[@]} == 5)) && [[ "${mycache[@]}" = '8 9 10 11 12' ]] && echo pass || echo fail

	ch_get mycache key2 && echo pass || echo fail
	((${#mycache[@]} == 4)) && [[ "${mycache[@]}" = '4 5 6 7' ]] && echo pass || echo fail

	! ch_get mycache key1 && echo pass || echo fail

	if (($#))
	then
		ncmp_read_dir "${@}"
	fi
fi
