#!/bin/bash


cat() {
	# Wrap cat to prevent catting large files.
	local args=()
	local limit=$((LINES*COLUMNS*10))
	while (($#))
	do
		case "${1}" in
			-h|--help)
				msg='usage: cat [flags...] [files...]

				Wrap cat and pipe to less if outputting to terminal and:
				1. Large data (>= limit)
				2. Any input files are binary

				Flags
				-l|--limit, case insensitive size limit before triggering behavior.
				    [Count][kmg][b]
				    kmg = kilo, mega, giga
				    b: use powers of 1000 instead of 1024
				-----------------------------------------
				'
				echo "${msg//$'\t'/}"
				command cat --help
				return
				;;
			-l|--limit)
				shift
				if [[ "${1,,}" =~ ^([[:digit:]]*)([kmg])?(b)?$ ]]
				then
					[[ -n "${BASH_REMATCH[3]}" ]] && limit=1000 || limit=1024
					case "${BASH_REMATCH[2]}" in
						k) : ;;
						m) ((limit=limit**2));;
						g) ((limit=limit**3));;
						*) limit=1;;
					esac
					((limit *= "${BASH_REMATCH[1]:-1}"))
				else
					echo "Invalid limit ${1}"
					return 1
				fi
				;;
			*) args+=("${1}");;
		esac
		shift
	done

	# not outputting to terminal
	# or input from terminal (no huge data), cat as normal
	if [[ ( ! -t 1 ) || ("${#args[@]}" -eq 0 && -t 0 ) || "${limit}" -le 0 ]]
	then
		command cat "${args[@]}"
		return
	fi
	if ((${#args[@]} == 0))
	then
		local buf
		# bash strings cannot contain null bytes
		if hash xxd &>/dev/null
		then
			buf=$(xxd -p < <(head -c "${limit}"))
			if (("${#buf}"*3 < limit*4 ))
			then
				echo -n "${buf}" | xxd -r -p
				command cat
			else
				{ echo -n "${buf}"; command cat; } | less
			fi
		else
			# no other choice?
			echo "Warning, no xxd, reading raw bytes into bash string (will lose data after nullbyte)" >&2
			read -N "${limit}" -r buf
			if (("${#buf}" < limit))
			then
				echo -n "${buf}"
				command cat
			else
				{ echo -n "${buf}"; command cat; } | less
			fi
		fi
	else
		if hash file &>/dev/null
		then
			if file --mime "${args[@]}" | grep -v '/x-empty' | grep 'charset=binary' &>/dev/null
			then
				command cat "${args[@]}" | less
				return
			fi
		fi
		local tot
		tot=$(du -bc "${args[@]}" | tail -n 1)
		if (("${tot%%[[:blank:]]*}" < limit))
		then
			command cat "${args[@]}"
		else
			command cat "${args[@]}" | less
		fi
	fi
}
