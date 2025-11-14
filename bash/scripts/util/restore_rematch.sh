#!/bin/bash

# BASH_REMATCH is a global array.
# A function call might or might not modify BASH_REMATCH.
# This allows functions to still use regex =~ operator
# but restore BASH_REMATCH as if it was never changed.
# user functions have less need to worry if any code
# might modify it while they are still using it.

if BASH_REMATCH=("${BASH_REMATCH[@]}")
then
	# BASH_REMATCH is rewritable
	restore_BASH_REMATCH() # <arrname>
	{
		# Restore BASH_REMATCH from <arrname>.
		# <arrname>: name of an array variable with the contents of the
		#            original BASH_REMATCH to restore.
		local -n shprbm__arr="${1}"
		BASH_REMATCH=("${shprbm__arr[@]}")
	}
else
	restore_BASH_REMATCH() # <arrname>
	{
		# Restore BASH_REMATCH from <arrname>.
		# <arrname>: name of an array variable with the contents of the
		#            original BASH_REMATCH to restore.
		local -n shprbm__arr="${1}"
		local shprbm__str='[[ "${shprbm__arr[0]}" =~ '
		local idx=0
		while ((++idx < ${#shprbm__arr[@]}))
		do
			shprbm__str+='("${shprbm__arr['${idx}']}").*'
		done
		eval "${shprbm__str} ]]"
	}
fi

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	[[ 'this is a string' =~ (this).*(string) ]]
	original=("${BASH_REMATCH[@]}")
	[[ 'asdf' =~ asdf ]]

	restore_BASH_REMATCH original

	if ((${#original[@]} != ${#BASH_REMATCH[@]})); then echo fail; exit 1; fi
	idx=-1
	while ((++idx < ${#original[@]}))
	do
		if [[ "${original[idx]}" != "${BASH_REMATCH[idx]}" ]]
		then
			echo fail
			exit 1
		fi
	done
	echo pass
fi
