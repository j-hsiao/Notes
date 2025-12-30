#!/bin/bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && declare -Fp restore_BASH_REMATCH &>/dev/null && (($# == 0)) && return

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
		local -n rbm__arr="${1}"
		BASH_REMATCH=("${rbm__arr[@]}")
	}
else
	echo 'WARNING: restore_BASH_REMATCH will fail of regex pattern has nested groups.' >&2
	restore_BASH_REMATCH() # <arrname>
	{
		# NOTE: this only works for non-nested groups...
		# Restore BASH_REMATCH from <arrname>.
		# <arrname>: name of an array variable with the contents of the
		#            original BASH_REMATCH to restore.
		local -n rbm__arr="${1}"
		local rbm__str='[[ "${rbm__arr[0]}" =~ '
		local rbm__idx=0
		while ((++rbm__idx < ${#rbm__arr[@]}))
		do
			rbm__str+='("${rbm__arr['${rbm__idx}']}").*'
		done
		eval "${rbm__str} ]]"
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
