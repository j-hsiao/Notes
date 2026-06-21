#!/bin/bash

arec()
{
	local out=
	local codec=
	local duration=()
	while (($#))
	do
		case "${1}" in
			-h|--help)
				echo 'arec [-h] [duration] [output]'
				;;
			*)
				if [[ "${1}" = +([0-9:]) ]]
				then
					duration=(-t "${1}")
				else
					out="${1}"
				fi
				;;
		esac
		shift
	done

	if [[ "${out}" = *.mp3 ]]
	then
		codec=(-c:a mp3)
	elif [[ "${out}" != *.* ]]
	then
		out="${out}.m4a"
		codec=(-c:a aac)
	fi
	local sink="$(pactl get-defautl-sink)"
	if [[ "${sink}" != *.monitor ]]
	then
		sink="${sink}.monitor"
	fi
	ffmpeg -f pulse -i "${sink}" -ac 2 \
		"${duration[@]}" "${codec[@]}" "${out}"
}
