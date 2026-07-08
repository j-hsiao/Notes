#!/bin/bash
# It seems like the only way to check integrity of a stream
# is to decode it and see if there are any problems.
# Store as rawvideo streams in a matroska container to reduce
# cpu usage from compression while decoding of all streams

ffcheck() {
	local verbose=0
	local quiet=0
	local play=0
	local fnames=()
	local loglevel=warning

	while (($#))
	do
		case "${1}" in
			-v|--verbose) verbose=1;;
			-q|--quiet) quiet=1;;
			-p|--play) play=1;;
			-h|--help)
				local msg='usage: ffcheck [-q] [-v] [-p] [-h] [-l loglevel] fnames...
				-q|--quiet: Only show files that had error/warning output.
				-v|--verbose: print the stderr from the ffmpeg command.
				-p|--play: Play the file with issues.
				-h|--help: display this message
				-l|--loglevel loglevel: Set the loglevel for ffmpeg'
				echo "${msg//$'\t'}"
				;;
			-l|--loglevel) loglevel="$2"; shift;;
			*)
				fnames+=("${1}")
				;;
		esac
		shift
	done
	local item
	for item in "${fnames[@]}"
	do
		local err="$(ffmpeg -loglevel warning -i "${item}" \
			-f matroska -map 0 -c:v rawvideo - 2>&1 >/dev/null)"
		if [[ -n "${err}" ]]
		then
			printf '* %s\x1b[K\n' "${item}"
			((verbose)) && echo "${err}"
			((play)) && ffplay -i "${item}" -loop 0
		else
			((quiet)) && printf '  %s\r' "${item}" \
				|| printf '  %s\n' "${item}"
		fi
	done
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	ffcheck "${@}"
fi
