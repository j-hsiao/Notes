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
	# Take input, determine start/duration
	local fname="${1}"
	if [[ -z "${fname}" ]]
	then
		echo 'Need input file.' >&2
		return 1
	fi
	if [[ "${fname}" != /* ]]
	then
		fname="${PWD}/${fname}"
	fi
	local oname="${2}"
	[[ -z "${oname}" || "${oname}" = "${fname}" ]] \
		&& oname="${fname%/*}/clip_${fname##*/}"

	echo "${fname} -> ${oname}"
	# ffplay "${fname}" -autoexit
	local beg= end= dur num
	while read -r -p "${beg} => ${end} (${dur}) >>> " line
	do
		local item ok=1
		for item in ${line}
		do
			case "${item}" in
				b*=*) beg="${item#*=}";;
				e*=*) end="${item#*=}";;
				[eq]*) return;;
				h*)
					msg='b[eg]=val: set the beginning of the clip.
						e[nd]=val: set the end of the clip.
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
		((ok)) && norm_time beg x && norm_time end x || continue
		if [[ -z "${end}" || "${end}" -lt "${beg}" ]]
		then
			dur=
		else
			if [[ -z "${beg}" ]]
			then
				dur="$((end/1000)).$((end%1000))"
			else
				dur=$((end - beg))
				dur="$((dur/1000)).$((dur%1000))"
				norm_time dur
			fi
		fi
		end="$((end/1000)).$((end%1000))"
		beg="$((beg/1000)).$((beg%1000))"
		norm_time beg
		norm_time end
		ffplay -autoexit ${beg:+-ss "${beg}"} ${dur:+-t "${dur}"} -i "${fname}"
	done
}
aclip "${@}"
