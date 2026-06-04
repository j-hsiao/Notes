#!/bin/bash

daystamps() # [start=0] [stop=start+7] [date=now]
{
	# Get the base timestamp for each day
	# Tool to get the base stamps for scheduled events.
	local start=0
	local stop=
	local datetime=0
	local now=now
	while (("${#}"))
	do
		case "${1}" in
			-h|--help)
				local msg='daystamps [-d] [-t now] [start[:stop]]
				-d: use date command to print time and timestamps
				start: starting offset from "now"
				stop: stop offset from "now"
				-t: set the "now" date explicitly instead of using actual "now"'
				echo "${msg//$'\t'}"
				return
				;;
			-t)
				shift
				now="${1}"
				;;
			-d)
				datetime=1
				;;
			*:*)
				start="${1%%:*}"
				stop="${1##*:}"
				;;
			*)
				start="${1}"
				;;
		esac
		shift
	done

	start="${start:-0}"
	stop="${stop:-start+7}"

	local epochsec weekday year month day hour minute second
	date '+%u %Y %m %d 1%H 1%M 1%S' -d "${now:-now}"
	read epochsec weekday year month day hour minute second < <(date '+%s %u %Y %m %d 1%H 1%M 1%S' -d "${now:-now}")
	local today=$((epochsec - ((hour-100)*60*60 + (minute-100)*60 + (second-100))))

	weekdays=(
		Monday
		Tuesday
		Wednesday
		Thursday
		Friday
		Saturday
		Sunday
	)

	for ((i=start; i<stop; ++i))
	do
		if ((datetime))
		then
			date '+%9A: %s : %Y-%m-%d %H:%M:%S' -d "@$((today + i*(24*60*60)))"
		else
			printf '%9s: %d\n' "${weekdays[(weekday + i - 1)%7]}" "$((today + i*(24*60*60)))"
		fi
	done
}

schedule_event_reminders() # timestamp=EPOCHSECONDS
{
	local fname="${1:-"${HOME}/.events"}"
	[[ -f "${fname}" ]] || return
	. "${fname}"
	local cleanup=()
	local pending=()
	local i
	local now="${1:-${EPOCHSECONDS}}"
	for ((i=0; i<${#events[@]}; i+=4))
	do
		local remainder=$((now-events[i]))
		if ((events[i+1] > 0))
		then
			((remainder%=events[i+1]))
		fi
		local time="${events[i+2]}"
		if ((0 < remainder))
		then
			if ((remainder < "(1${time%%:*}-100)" * 60*60 + "(1${time##*:}-100)" * 60))
			then
				pending+=("${events[@]:i+2:2}")
			elif ((events[i+1] < 0))
			then
				cleanup+=("${events[@]:i:i+4}")
			fi
		fi
	done
	if ((${#pending[@]}))
	then
		rem "${pending[@]}"
	fi

	# =======
	# cleanup
	# =======
	if ((${#cleanup[@]}))
	then
		printf '%s\n' \
			'----------------' \
			'cleanup required' \
			'----------------'
		local lines=()
		local todelete=()
		readarray -t lines <"${fname}"
		for ((i=0; i<${#cleanup[@]}; i+=4))
		do
			local candidates=()
			local j
			for ((j=0; j<"${#lines[@]}"; ++j))
			do
				if [[ "${lines[j]}" = *([[:blank:]])"${cleanup[i]}"*"${cleanup[i+2]}"* ]]
				then
					candidates+=("${j}")
				fi
			done
			if (("${#candidates[@]}" == 1))
			then
				if ((${#todelete[@]} == 0 || todelete[-1] < candidates[0]))
				then
					todelete+=("${candidates[0]}")
				else
					echo "BAD BAD BAD, everything should be monotonically increasing but it was not!"
					echo "to delete: ${todelete[@]}"
					echo "candidates: ${candidates[@]}"
				fi
			else
				echo 'Ambiguous cleanup'
				echo "old: ${cleanup[@]:i:i+4}"
				for j in "${#candidates[@]}"
				do
					printf 'candidate: %q\n' "${lines[j]}"
				done
			fi
		done
		local tmp=("${lines[@]/#/    }")
		for idx in "${todelete[@]}"
		do
			tmp[idx]=$'-\e[31;40m'"${tmp[idx]# }"$'\e[0m'
		done
		printf '%s\n' "${tmp[@]}"
		echo 'okay?'
		local response
		read response
		if [[ "${response}" = [yY]* ]]
		then
			for idx in "${todelete[@]}"
			do
				unset lines[idx]
			done
			printf '%s\n' "${lines[@]}" > "${fname}"
		fi
	fi
}
if ! declare -f rem &>/dev/null
then
	. "${BASH_SOURCE[0]%event.sh}remind.sh"
fi
schedule_event_reminders "${@}"
