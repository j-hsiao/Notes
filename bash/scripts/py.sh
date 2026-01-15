#!/bin/bash

if [[ -d /cygdrive ]] && type -fP py &>/dev/null
then
	# cygwin with windows py
	py()
	{
		local paths=() args=("${@}") idxs=() idx=-1
		# cygwin command substitution is very slow
		# multiple paths would multiply the slowdown...
		while ((++idx < ${#args[@]}))
		do
			if [[ "${args[idx]:0:1}" = '/' ]]
			then
				paths+=("${args[idx]}")
				idxs+=("${idx}")
			fi
		done

		if ((${#paths[@]}))
		then
			readarray -t paths < <(cygpath -w "${paths[@]}")
			idx=-1
			while ((++idx < ${#paths[@]}))
			do
				args[idxs[idx]]="${paths[idx]}"
			done
		fi

		# cygwin TZ setting seems to mess up windows python datetime
		env TZ= command py "${args[@]}"
	}

else
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
				if type python &>/dev/null
				then
					command python "${@}"
				else
					command python3 "${@}"
				fi
				;;
		esac
	}
fi
