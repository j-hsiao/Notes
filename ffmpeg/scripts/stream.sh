#!/bin/bash
# stream the input videos to corresponding index

download_mediamtx() {
	# download mediamtx using link to the specified directory
	local link="${1}" target="${2}"
	local orig="${PWD}"
	mkdir -p "${target}" \
		&& cd "${target}" \
		&& wget "${link}" \
		&& tar -xzf "${link##*/}" \
		&& cd "${orig}" \
		&& [[ -f "${target}/mediamtx" ]]
}

get_mediamtx() {
	# download mediamtx to the specified directory
	echo "Downloading mediamtx..."
	local target="${1}"
	case "$(uname -o)" in 
		*Linux*)
			case "$(uname -m)" in
				x86_64)
					download_mediamtx 'https://github.com/bluenviron/mediamtx/releases/download/v1.14.0/mediamtx_v1.14.0_linux_amd64.tar.gz' "${target}"
					return
					;;
				aarch64)
					download_mediamtx 'https://github.com/bluenviron/mediamtx/releases/download/v1.14.0/mediamtx_v1.14.0_linux_arm64.tar.gz' "${target}"
					return
					;;
			esac
			;;
	esac
	return 1
}

find_fmt() {
	local line
	local -n find_fmt_out="${2:-OUT}"
	while read line
	do
		if [[ "${line}" =~ format_name=.* ]]
		then
			find_fmt_out="${line#*=}"
			return
		fi
	done < <(ffprobe -loglevel error -i "${1}" -show_entries format=format_name 2>/dev/null)
	find_fmt_out=
}

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
stream_vids() {
	local NAMES=()
	local CAMS=()
	local idx=0
	local rtspnamebase=camera
	local TARGET=
	local RUN_MEDIAMTX=1
	local USE_PYTHON=0
	local USE_PIPE=0
	local IEXTRA=()
	local XEXTRA=()
	local SEP=
	while ((idx < ${#}))
	do
		case "${1}" in
			-p|--python)
				shift
				USE_PYTHON=1
				local x
				for x in "${@}"
				do
					case "${x}" in
						-t|--target|-h|--help)
							RUN_MEDIAMTX=0
							;;
					esac
				done
				break
				;;
			--sep)
				shift
				SEP="${1}"
				USE_PIPE=${#SEP}
				;;
			--pipe)
				USE_PIPE=1
				;;
			-t|--target)
				if [[ "${2}" =~ -.* ]]
				then
					TARGET=
				else
					shift 1
					TARGET="${1}"
				fi
				RUN_MEDIAMTX=0
				;;
			-n|--name)
				shift
				rtspnamebase="${1}"
				;;
			-h|--help)
				HELP_MSG="usage: ${BASH_SOURCE[0]} [-n] [video...]
[-p|--python]
	Use python instead of using ffmpeg directly.  The remaining arguments
	will be passed to the python syncstream.py script.  Any prior arguments
	are discarded.
[--pipe]
	Use pipes instead of \`-stream_loop -1\` because some systems seem to
	have issues with the stream_loop method resulting in hanging.  This method
	requires the inputs to be \`cat\`able into a valid stream.
	example: h264 (eg .h264 rather than .mp4)
[--sep] <sep>
	--sep implies --pipe.  The input video sources are interpreted as groups
	of videos to be \`cat\` together as a single rtsp stream source.  These
	groups are delimited by <sep>.
	ex: bash stream.sh --sep MYSEP v1 v2 v3 MYSEP v4 v5 v6 MYSEP v7
	In this case, v1, v2, and v3 will be treated as stream1.
	v4, v5, v6 will be treated as stream2
	v7 will be treated as stream3.
	Any extra arguments will only be taken from the first of each set
	(such as name=*)
[-t|--target] [target='rtsp://localhost:8554']
	target rtsp url without the stream name.  If target is specified,
	then assume that the rtsp server already exists.  In this case,
	mediamtx will NOT be run.
[-n|--name]
	basename for default rtsp stream name, defaults to 'camera'
	Default streamname will be this followed by the argument index from 1.
	eg. 'camera2' would be the 2nd argument's default rtsp name.
[video...]
	name of the video to become an rtsp stream source.
	Can be prefixed with arguments delimited by '::'
	ex:
		custom_rtsp_name::asdf.mp4
	will stream asdf.mp4 under rtsp://localhost:8554/custom_rtsp_name
	ex:
		name=custom_rtsp_name::asdf.mp4
	same as above but specify argument name.
"
				echo "${HELP_MSG}"
				return 1
				;;
			*)
				local iname="${1}" arg camname extra_args=()
				while [[ "${iname}" =~ .*::.* ]]
				do
					arg="${iname%%::*}"
					iname="${iname#*::}"
					case "${arg}" in
						name=*)
							camname="${arg#camname=}"
							;;
						*=*)
							extra_args+=("-${arg%%=*}" "${arg#*=}")
							;;
						*)
							camname="${arg}"
							;;
					esac
				done
				XEXTRA+=("${#IEXTRA[@]}" "${#extra_args[@]}")
				IEXTRA+=("${extra_args[@]}")
				CAMS+=("${iname}")
				NAMES+=("${camname}")
				;;
		esac
		shift
	done

	if ((RUN_MEDIAMTX))
	then
		local MEDIAMTX
		if [[ -f "${ROOTDIR}/mediamtx/mediamtx" ]]
		then
			MEDIAMTX="${ROOTDIR}/mediamtx/mediamtx"
		elif type mediamtx 2>/dev/null
		then
			MEDIAMTX="$(type -p mediamtx)"
		elif get_mediamtx "${ROOTDIR}/mediamtx"
		then
			MEDIAMTX="${ROOTDIR}/mediamtx/mediamtx"
		else
			echo "Cannot find mediamtx." >&2
			echo "Please download from https://github.com/bluenviron/mediamtx/releases and" >&2
			echo "place the executable at path \"${ROOTDIR}/mediamtx/mediamtx\"" >&2
			return 1
		fi

		"${MEDIAMTX}" "${MEDIAMTX}.yml" &
		local mtxpid=$!
		sleep 1
	fi

	if ((USE_PYTHON))
	then
		if type python3 2>/dev/null
		then
			PY_EXE=python3
		elif type python 2>/dev/null
		then
			PY_EXE=python
		else
			echo 'Python not found.' >&2
			return 1
		fi
		"${PY_EXE}" "${ROOTDIR}/syncstream.py" "${@}"
	else
		if ((USE_PIPE))
		then
			# NOTE using a single ffmpeg to feed and a single ffmpeg to read will fail.
			# The reader may be blocked on file A, but the feeder might be blocked on file B.
			# Instead either all feeders or all readers should be separate processes.  Using
			# a single process for reading should probably keep the streams in sync better
			# since they all stem from a single process with only a single start time.
			# NOTE: using exec redirection and pipe:${fd} will cause ffmpeg to NOT read stdin
			# so pressing q will do nothing.  It seems like the best choice is still to build
			# a commandline and then run it as a script. (using <(while cat...) directly
			# as an argument allows for ffmpeg to read q to quit)
			local INPUTS= OUTPUTS= idx=0
			while ((idx < "${#CAMS[@]}"))
			do
				if ((XEXTRA[idx*2 + 1]))
				then
					INPUTS+="$(printf '%q ' "${IEXTRA[@]:XEXTRA[idx*2]:XEXTRA[idx*2 + 1]}")"
				fi
				local found=0 arg
				for arg in "${IEXTRA[@]:XEXTRA[idx*2]:XEXTRA[idx*2 + 1]}"
				do
					if [[ "${arg}" = "-f" ]]
					then
						found=1
						break
					fi
				done
				if ((!found))
				then
					find_fmt "${CAMS[idx]}" arg
					INPUTS+="-f $(printf '%q ' "${arg}")"
				fi
				OUTPUTS+="$(printf '%q ' -map "${idx}:v" -c:v copy -f rtsp -rtsp_transport tcp "${TARGET:-rtsp://localhost:8554}/${NAMES[idx]:-${rtspnamebase}$((idx+1))}")"
				if [[ -z "${SEP}" ]]
				then
					INPUTS+="-re -i <(while cat $(printf '%q' "${CAMS[idx]}"); do :; done) "
				else
					local startidx="${idx}"
					while ((idx < ${#CAMS[@]})) && [[ "${CAMS[idx]}" != "${SEP}" ]]
					do
						((++idx))
					done
					INPUTS+="-re -i <(while cat $(printf '%q ' "${CAMS[@]:startidx:idx-startidx}"); do :; done) "
				fi
				((++idx))
			done
			local bashscript="ffmpeg ${INPUTS} ${OUTPUTS}"
			echo "${bashscript}" >&2
			bash -c "${bashscript}"
		else
			local INPUTS=()
			local OUTPUTS=()
			idx=0
			while ((idx < "${#CAMS[@]}"))
			do
				INPUTS+=(-stream_loop -1 -re "${IEXTRA[@]:XEXTRA[idx*2]:XEXTRA[idx*2 + 1]}" -i "${CAMS[idx]}")
				OUTPUTS+=(-map "${idx}:v" -c:v copy -f rtsp -rtsp_transport tcp "${TARGET:-rtsp://localhost:8554}/${NAMES[idx]:-${rtspnamebase}$((idx+1))}")
				((++idx))
			done
			echo ffmpeg "${INPUTS[@]}" "${OUTPUTS[@]}" >&2
			ffmpeg "${INPUTS[@]}" "${OUTPUTS[@]}"
		fi
	fi
	if ((RUN_MEDIAMTX))
	then
		if kill -0 "${mtxpid}" 2>/dev/null
		then
			kill "${mtxpid}"
			wait
		fi
	fi
}

stream_vids "${@}"
