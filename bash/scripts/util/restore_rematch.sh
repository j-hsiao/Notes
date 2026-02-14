#!/bin/bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && declare -Fp restore_BASH_REMATCH &>/dev/null && (($# == 0)) && return

# BASH_REMATCH is a global array.
# A function call might or might not modify BASH_REMATCH
# because it uses [[ ... =~ ... ]].  However, caller
# might not be aware.  To avoid forcing callers to be
# aware if BASH_REMATCH might be modified, these functions
# allow restoring BASH_REMATCH to a given value so callers
# don't need to bother with this.  The alternative would be
# to always copy BASH_REMATCH to a local array and use that
# but it's easier if function calls won't modify BASH_REMATCH.

# assignment to readonly not only fails, it doesn't even take the else case
# so cannot just check if BASH_REMATCH is assignable...
if ((BASH_VERSINFO[0] > 5 || BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))
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
	restore_BASH_REMATCH_popstack()
	{
		if ((rbm__stack[-2] < rbm__stack[-1]))
		then
			rbm__str+=('"${rbm__arr[0]:'"${rbm__stack[-2]}:$((rbm__stack[-1] - rbm__stack[-2]))"$'}"\x29')
		else
			rbm__str+=($'\x29')
		fi
		((rbm__stack[-4] = rbm__stack[-1]))
		unset rbm__stack[-1]
		unset rbm__stack[-1]
	}

	restore_BASH_REMATCH() # <arrname>
	{
		# NOTE: this only works for non-nested groups...
		# Restore BASH_REMATCH from <arrname>.
		# <arrname>: name of an array variable with the contents of the
		#            original BASH_REMATCH to restore.
		#
		# algorithm:
		# start with full range 0-len
		# For each item, if in prevrange:

		local -n rbm__arr="${1}"
		local rbm__idx
		local rbm__rem="${rbm__arr[0]}"
		local rbm__str=('[[ "${rbm__arr[0]}" =~ ')
		local rbm__stack=(0 ${#rbm__arr[0]})
		local rbm__chunks=()
		local rbm__i
		for ((rbm__i=1; rbm__i < ${#rbm__arr[@]}; ++rbm__i))
		do
			local rbm__pre="${rbm__arr[0]:rbm__stack[-2]:rbm__stack[-1] - rbm__stack[-2]}"
			while [[ "${rbm__pre}" != *"${rbm__arr[rbm__i]}"* ]]
			do
				restore_BASH_REMATCH_popstack
				rbm__pre="${rbm__arr[0]:rbm__stack[-2]:rbm__stack[-1] - rbm__stack[-2]}"
			done
			local rbm__head="${rbm__pre%%"${rbm__arr[rbm__i]}"*}"
			if (("${#rbm__head}"))
			then
				rbm__str+=('"${rbm__arr[0]:'"${rbm__stack[-2]}:${#rbm__head}"$'}"\x28')
			else
				rbm__str+=($'\x28')
			fi
			rbm__stack+=($((rbm__stack[-2] + ${#rbm__head})))
			rbm__stack+=($((rbm__stack[-1] + ${#rbm__arr[rbm__i]})))
		done
		while ((${#rbm__stack[@]} > 2))
		do
			restore_BASH_REMATCH_popstack
		done
		rbm__str+=("${rbm__arr[0]:rbm__stack[0]:rbm__stack[1]-rbm__stack[0]}")
		local IFS=
		local pat="${rbm__str[*]} ]]"
		eval "${pat}"
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

	[[ 'this is a blue orange' =~ (t[^[:blank:]]*).*(b.*(o.*)) ]]
	original=("${BASH_REMATCH[@]}")
	[[ '' =~ '' ]]
	restore_BASH_REMATCH original
	[[ "${#original[@]}" -ne "${#BASH_REMATCH[@]}" || "${original[*]/%/,}" != "${BASH_REMATCH[*]/%/,}" ]] \
		&& echo fail && exit 1 \
		|| echo pass
fi
