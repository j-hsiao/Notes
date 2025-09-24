#!/bin/bash

ac_make() # <name> <size>
{
	# Create a cache.
	# The cache consists of a set of variables:
	# 1. nameref: This points to the corresponding chosen cache entry and
	#             matches <name>
	# 2. key: This tracks the key and corresponding actual variable
	# 3. entries: These variables are the actual cache entries.
	declare -gn "${1}"="${1}0"
	local -n acmk__arr="${1}idx"
	acmk__arr=()
	local idx=0
	while ((idx < ${2}))
	do
		acmk__arr[idx*2]=""
		acmk__arr[idx*2 + 1]="${1}${idx}"
		local -n acmk__sub="${1}${idx}"
		acmk__sub=()
		((++idx))
	done
}

ac_get() # <name> <key>
{
	# Point <name> to the corresponding cache entry.
	# If it does not exist, create a new one, possibly invalidating
	# the oldest entry.  If found, then return code 0
	# If new, then return code 1
	local -n acgt__arr="${1}idx"
	local idx=0
	while ((idx < ${#acgt__arr[@]}))
	do
		if [[ "${acgt__arr[idx]}" = "${2}" ]]
		then
			local pick="${acgt__arr[++idx]}"
			while ((idx >= 2))
			do
				acgt__arr[idx]="${acgt__arr[idx-2]}"
				((--idx))
			done
			acgt__arr[0]="${2}"
			acgt__arr[1]="${pick}"
			declare -gn "${1}"="${pick}"
			return 0
		fi
		((idx += 2))
	done
	acgt__arr=("${acgt__arr[@]:idx-2}" "${acgt__arr[@]:0:idx-2}")
	acgt__arr[0]="${2}"
	declare -gn "${1}=${acgt__arr[1]}"
	local -n acgt__arr="${acgt__arr[1]}"
	acgt__arr=()
	return 1
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo "Testing cache."
	echo "Make Cache."
	ac_make mycache 3
	((${#mycacheidx[@]} == 6)) && echo pass || echo fail
	((${#mycache[@]} == 0)) && echo pass || echo fail

	echo "Testing create new entry."
	! ac_get mycache key1 && echo pass || echo fail
	mycache=(1 2 3)
	! ac_get mycache key2 && echo pass || echo fail
	mycache=(4 5 6 7)

	echo "Retrieve existing entry."
	ac_get mycache key1 && echo pass || echo fail
	((${#mycache[@]} == 3)) && echo pass || echo fail

	echo "Create new entry"
	! ac_get mycache key3 && echo pass || echo fail
	mycache=(8 9 10 11 12)


	echo "Retrieve existing entries."
	ac_get mycache key1 && echo pass || echo fail
	((${#mycache[@]} == 3)) && [[ "${mycache[@]}" = '1 2 3' ]] && echo pass || echo fail

	ac_get mycache key3 && echo pass || echo fail
	((${#mycache[@]} == 5)) && [[ "${mycache[@]}" = '8 9 10 11 12' ]] && echo pass || echo fail

	ac_get mycache key2 && echo pass || echo fail
	((${#mycache[@]} == 4)) && [[ "${mycache[@]}" = '4 5 6 7' ]] && echo pass || echo fail

	echo "Invalidate oldest entry."

	! ac_get mycache key4 && echo pass || echo fail
	((${#mycache[@]} == 0)) && echo pass || echo fail

	ac_get mycache key3 && echo pass || echo fail
	((${#mycache[@]} == 5)) && [[ "${mycache[@]}" = '8 9 10 11 12' ]] && echo pass || echo fail

	ac_get mycache key2 && echo pass || echo fail
	((${#mycache[@]} == 4)) && [[ "${mycache[@]}" = '4 5 6 7' ]] && echo pass || echo fail

	! ac_get mycache key1 && echo pass || echo fail
	((${#mycache[@]} == 0)) && echo pass || echo fail

fi
