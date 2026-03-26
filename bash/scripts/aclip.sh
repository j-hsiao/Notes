#!/bin/bash

if [[ "${0}" != "${BASH_SOURCE[0]}" ]]
then
	if [[ "${BASH_SOURCE[0]}" = /* ]]
	then
		aclip() { bash "${BASH_SOURCE[0]}" "${@}"; }
	else
		. "${PWD}/${BASH_SOURCE[0]}"
	fi
	return
fi

calc_dur() # beg end [*dur]
{
	# Calculate the duration between beg and end as HH:MM:SS.mmm
	# If end is empty or end < beg, then dur is empty.
	# Fails if beg or end are not valid timestamps.
	local calcdur__beg="${1:-0}"
	local calcdur__end="${2}"
	local -n calcdur__dur="${3:-dur}"
	if ! { norm_time calcdur__beg x && norm_time calcdur__end x; }
	then
		local IFS=-
		echo "Invalid timestamps ${-:1:2}" >&2
		return 1
	fi
	if [[ -z "${calcdur__end}" || "${calcdur__end}" -lt "${calcdur__beg}" ]]
	then
		calcdur__dur=
	else
		calcdur__dur=$((calcdur__end - calcdur__beg))
		calcdur__dur="$((calcdur__dur/1000)).$((calcdur__dur%1000))"
		norm_time calcdur__dur
	fi
}


norm_time() # tmvar [msec]
{
	# Normalize a time string.
	# if msec, then return number of milliseconds.
	local -n __num="${1}"
	[[ -z "${__num}" ]] && return
	if ! [[ "${__num}" =~ ^(0*([0-9]*):)?(0*([0-9]*):)?(0*([0-9]*))(\.([0-9]*))?$ ]]
	then
		echo "${1} is not valid: ${__num}"
		return 1
	fi
	local __hours __minutes __seconds __msecs
	if [[ -z "${BASH_REMATCH[3]}" ]]
	then
		__hours=0
		__minutes="${BASH_REMATCH[2]%:}"
	else
		__hours="${BASH_REMATCH[2]%:}"
		__minutes="${BASH_REMATCH[4]%:}"
	fi
	__msecs="${BASH_REMATCH[8]}000"
	__msecs="${__msecs::3}"
	__hours="${__hours:-0}"
	__minutes="${__minutes:-0}"
	__seconds="${BASH_REMATCH[6]:-0}"

	__seconds=$((__hours*3600 + __minutes*60 + __seconds))
	if [[ -z "${2}" ]]
	then
		printf -v "${1}" '%02d:%02d:%02d.%.3s' \
			$((__seconds/3600)) \
			$(((__seconds%3600) / 60)) \
			$((__seconds%60)) \
			${__msecs}
	else
		__num="$((__seconds*1000 + 1${__msecs} - 1000))"
	fi
}

aclip() # input [output]
{
	local rangepat='*([0-9.:])-*([0-9.:])'
	shopt -s extglob nullglob

	local fname oname beg= end= dur item ok
	while (($#))
	do
		case "${1}" in
			e=*) end="${1:2}" ;;
			b=*) beg="${1:2}" ;;
			${rangepat}) end="${1##*-}"; beg="${1%%-*}";;
			-h|--help)
				msg="usage: ${0##*/} <input> [output=clip_\${input}] [b=t1] [e=t2] [t1-t2]
				b=t1, e=t2: set the beginning and ending timestamps
				t1-t2     : merged setting timestamp."
				echo "${msg//$'\t'}" >&2
				return
				;;
			*) [[ -z "${fname}" ]] && fname="${1}" || oname="${1}";;
		esac
		shift 1
	done

	# Take input, determine start/duration
	if [[ -z "${fname}" ]]
	then
		echo 'Need input file.' >&2
		return 1
	fi
	if [[ "${fname}" != /* ]]
	then
		fname="${PWD}/${fname}"
	fi
	if [[ -z "${oname}" || "${oname}" = "${fname}" ]]
	then
		local pre=${fname%.*}
		local ext="${fname##*.}"
		multinum='+([0-9])'
		local clips=("${pre}"clip${multinum}*."${ext}")
		oname="${pre}clip${#clips[@]}.${fname##*.}"
		printf '%s\n' "${clips[@]}"
	fi

	echo "${fname} -> ${oname}"
	# ffplay "${fname}" -autoexit
	while :
	do
		norm_time beg
		norm_time end
		calc_dur "${beg}" "${end}" dur \
			&& ffplay -autoexit ${beg:+-ss "${beg}"} ${dur:+-t "${dur}"} -i "${fname}"
		printf '\n%8s => %8s (%8s) >>> ' "${beg}" "${end}" "${dur}"
		read -r line || return
		ok=1
		for item in ${line}
		do
			case "${item}" in
				b=*) beg="${item#*=}";;
				e=*) end="${item#*=}";;
				${rangepat}) beg="${item%%-*}"; end="${item##*-}";;
				[eq]*) return;;
				h*)
					msg='b[eg]=val: set the beginning of the clip.
						e[nd]=val: set the end of the clip.
						t1-t2: set beginning and end simultaneously
						e[xit]|q[uit]: exit clipping.
						r[eplace]: clip and replace the original.
						y[es]: clip, do not replace.  Use 2nd argument if given.'
					printf "${msg//$'\t'}" >&2
					ok=0
					;;
				[ry]*)
					ffmpeg ${beg:+-ss "${beg}"} -i "${fname}" -c:a copy ${dur:+-t "${dur}"} "${oname}"
					if [[ "${item}" = r ]]
					then
						mv "${oname}" "${fname}"
					fi
					return
					;;
				*)
					echo "recognized token: ${item}" >&2
					ok=0
					;;
			esac
		done
	done
}
aclip "${@}"
