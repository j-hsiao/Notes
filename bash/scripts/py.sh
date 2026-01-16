#!/bin/bash

# hash -t is very fast, checking if the corresponding
# item is hashed or not.  However, using type, etc
# is very slow.
#
# Also, if a function of the same name exists, hash will
# succeed, but hash -t WILL ALWAYS FAIL.  However, if
# the actual command is first hashed, before the function
# is defined, then everything works ok.

if [[ -d /cygdrive ]] && type -fP py &>/dev/null
then
	# hash before function definition so py is hashed properly
	hash py
	py()
	{
		local paths=() args=("${@}") idxs=() idx
		# Correct paths from cygwin to windows.
		# Try to avoid using process substitution
		# because so slow.
		for ((idx=0; idx<${#args[@]}; ++idx))
		do
			if [[ "${args[idx]}" = /cygdrive/[a-zA-Z]/* ]]
			then
				args[idx]="${args[idx]/#\/cygdrive\/}"
				args[idx]="${args[idx]/['\/']/:/}"
			elif [[ "${args[idx]}" = /* ]]
			then
				paths+=("${args[idx]}")
				idxs+=("${idx}")
			fi
		done
		if ((${#paths[@]}))
		then
			readarray -t paths < <(cygpath -w "${paths[@]}")
			for ((idx=0; idx<${#paths[@]}; ++idx))
			do
				args[idxs[idx]]="${paths[idx]}"
			done
		fi
		# cygwin TZ setting seems to mess up windows python datetime
		TZ= command py "${args[@]}"
	}
else
	hash py python2 python3 python &>/dev/null
	py()
	{
		case "${1}" in
			-2)
				shift
				command python2 "${@}"
				;;
			-3)
				shift
				command python3 "${@}"
				;;
			*)
				if hash -t python &>/dev/null
				then
					command python "${@}"
				else
					command python3 "${@}"
				fi
				;;
		esac
	}
fi
