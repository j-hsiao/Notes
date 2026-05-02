#!/bin/bash

if [[ "${0}" != "${BASH_SOURCE[0]}" ]]
then
	if [[ "${BASH_SOURCE[0]}" != /* ]]
	then
		. "${PWD}/${BASH_SOURCE[0]}"
		return
	fi
	autoclick() { bash "${BASH_SOURCE[0]}"; }
	return
fi

autoclick() # count [unit=10]
{
	local delay=1000
	local count=1
	local unit=10
	while (($#))
	do
		case "${1}" in
			-h|--help|help|'?')
				local msg='count [-h] [-u unit] [-d delay_msec=1000]
				count: number of clicks
				unit: clicks between checks for cancelling.
				delay: delay between clicks
				'
				echo "${msg//$'\t'}"
				return
				;;
			q|quit|exit) return 1 ;;
			-u)
				shift
				unit="${1}"
				;;
			-d)
				shift
				delay="${1}"
				;;
			*)
				if [[ "${1}" = @(0|[1-9]*([0-9])) ]]
				then
					count="${1}"
				else
					printf 'Bad count %s\n' "${1}"
					return
				fi
		esac
		shift
	done

	local tstep=$((delay / 2))
	((tstep = tstep > 50 ? 50 : tstep))
	((tstep <= 0 ? 1 : tstep))
	local steps=(0xc0)
	local idx
	for ((idx=tstep*2; idx<delay; idx+=tstep))
	do
		steps+=(0x00)
	done
	for ((idx=0; idx<count; idx+=unit))
	do
		echo "${idx} / ${count}"

		if ((idx+unit > count))
		then
			((unit = count-idx))
		fi

		ydotool click --next-delay "${tstep}" --repeat "${unit}" "${steps[@]}" &>/dev/null
		if read -t 0
		then
			read idx # consume interrupt input
			return
		fi
	done
}

run()
{
	if [[ "${USER}" != root ]]
	then
		# activate sudo for ydotoold
		sudo env YDOTOOL_SOCKET="${1:-"${XDG_RUNTIME_DIR}/autoclick$$.sock"}" \
			bash "${BASH_SOURCE[0]}"
		return
	elif [[ -z "${YDOTOOL_SOCKET}" ]]
	then
		# calculate default YDOTOOL_SOCKET if not set
		if [[ -d "/dev/shm" ]]
		then
			export YDOTOOL_SOCKET="/dev/shm/autoclick$$.sock"
		else
			echo "YDOTOOL_SOCKET not set" >&2
			return
		fi
	fi
	if [[ "${1}" = 'ydotoold' ]]
	then
		# The ydotoold process
		# Handle cleanup
		# Because coproc seems to make an intermediate process
		# killing the pid of the coproc does not kill this script
		# therefore must communicate the pid of current process
		# read to wait for parent to know the correct pid.
		# Afterwards, start ydotoold and then finally cleanup.
		echo "pid: $$"
		read
		stdbuf -o L ydotoold -p "${YDOTOOL_SOCKET}" &
		pid=$!
		trap 'trap - RETURN
			kill "${pid}"
			rm "${YDOTOOL_SOCKET}"
			wait "${pid}"' RETURN
		read
		return
	fi
	coproc ydo { stdbuf -o L bash "${BASH_SOURCE[0]}" ydotoold; }
	trap 'trap - RETURN; ((${#ydo[@]})) && echo >&"${ydo[1]}"' RETURN
	local line
	read -u ${ydo[0]} line
	if [[ "${line}" != 'pid: '[1-9]*([0-9]) ]]
	then
		echo "Failed to start ydotoold."
		echo >&"${ydo[1]}"
		return
	fi
	echo >&"${ydo[1]}"

	local ready=0
	while read -t 10 -u ${ydo[0]} line
	do
		echo "ydotoold: ${line}"
		if [[ "${line}" = *READY* ]]
		then
			ready=1
			break
		fi
	done
	if ((!ready))
	then
		echo "ydotoold failed to ready"
		return
	fi

	echo 'type -h for help'
	local count=1
	while read -r -p '>>> ' line
	do
		count="${line:-${count}}"
		if ! autoclick ${count}
		then
			break
		fi
		if read -t 0 -u ${ydo[0]}
		then
			read -u ${ydo[0]} line
			[[ -n "${line}" ]] && echo "ydotoold: ${line}"
		fi
	done
}
run "${@}"
