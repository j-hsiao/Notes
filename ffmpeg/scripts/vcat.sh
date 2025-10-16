#!/bin/bash
# concatenate various inputs using ffmpeg


get_pattern() {
	local -n get_presuffix_arr="${1}"
	local -n get_presuffix_out="${2:-OUT}"
	local -n get_presuffix_prelen="${3:-PRELEN}"
	local -n get_presuffix_suflen="${4:-SUFLEN}"

	local reference="${get_presuffix_arr[0]}" pathidx=1 charidx
	local prelen="${#reference}"
	local postlen="${#reference}"
	local uniformlen=1
	while ((pathidx < ${#get_presuffix_arr[@]}))
	do
		local fname="${get_presuffix_arr[pathidx]}"
		uniformlen=$((uniformlen && "${#fname}" == "${#reference}"))
		while ((prelen)) && [[ "${fname:0:prelen}" != "${reference:0:prelen}" ]]
		do
			((--prelen))
		done
		while ((postlen)) && [[ "${fname:${#fname}-postlen:postlen}" != "${reference:${#reference}-postlen:postlen}" ]]
		do
			((--postlen))
		done
		((++pathidx))
	done
	get_presuffix_prelen=${prelen}
	get_presuffix_suflen=${postlen}
	if ((uniformlen))
	then
		get_presuffix_out="${reference:0:prelen}%0$((${#reference} - (prelen+postlen)))d${reference:${#reference}-postlen:postlen}"
	else
		get_presuffix_out="${reference:0:prelen}%d${reference:${#reference}-postlen:postlen}"
	fi
}

guess_name() {
	local path="${1}" bname dname
	local guess_name_bak="${2}"
	local -n guess_name_out="${3:-OUT}"
	if [[ -f "${path}" ]]
	then
		# filename is probably name of camera
		# so the dirname is the name of the case
		dname="$(basename "$(dirname "${path}")")"
		bname="$(basename "${path}")"
	elif [[ "${path}" =~ .*%[0-9]*d.*\.(jpg|jpeg|png) ]]
	then
		# ffmpeg image sequence
		dname="$(dirname "${path}")"
		bname="$(basename "${dname}")"
		dname="$(basename "$(dirname "${dname}")")"
	else
		guess_name_out="${guess_name_bak}"
		return
	fi
	guess_name_out="${dname}/${bname}"
}


gather_info() {
	local -n gather_info_inputs="${1}"
	local -n gather_info_IFPS="${2:-IFPS}"
	local -n gather_info_AFPS="${3:-AFPS}"
	local -n gather_info_WIDTH="${4:-WIDTH}"
	local -n gather_info_HEIGHT="${5:-HEIGHT}"

	local idx=0 line
	while ((idx < ${#gather_info_inputs[@]}))
	do
		while read line
		do
			case "${line}" in
				width=*)
					gather_info_WIDTH+=("${line#width=}")
					;;
				height=*)
					gather_info_HEIGHT+=("${line#height=}")
					;;
				r_frame_rate=*)
					gather_info_IFPS+=("${line#r_frame_rate=}")
					;;
				avg_frame_rate=*)
					gather_info_AFPS+=("${line#avg_frame_rate=}")
					;;
			esac
		done < <(ffprobe -loglevel error -i "${gather_info_inputs[idx]}" -show_entries stream=width,height,r_frame_rate,avg_frame_rate)
		((++idx))
	done
}

calc_max() {
	local -n calc_max_arr="${1}"
	local -n calc_max_out="${2:-OUT}"
	local idx=0 best=
	while ((idx < ${#calc_max_arr[@]}))
	do
		if ((${#best} == 0 || calc_max_arr[idx] > best))
		then
			best="${calc_max_arr[idx]}"
		fi
		((++idx))
	done
	calc_max_out="${best}"
}



run() {
	HELP_MSG="usage: ${0} [-n] [-t secs] [-f fps] [inputs...] [-o out]

[-n|--number_frames]
	add numbers to frames
[-f|--fps] fps
	Specify target fps
[-s|--size] WxH
	The output video size.
[-g|--gop] nframes
	Specify size of GOP (Group of Pictures).  Every \`nframes\` frames,
	add an iframe.  Defaults to 1 iframe per second.  Give empty or 0
	value for no GOP (only 1 iframe at the very beginning)  This would
	give the best compression, but streaming must start at the very
	beginning since Iframes are required to decode all the other
	frames.
[-t|--title] [secs=3]
	Add title card for following inputs for \`secs\` seconds.
[-o|--out]
	Output file name.  Defaults to out.mp4
[--oflags]
	Explicitly specify extra ffmpeg output arguments.
[[title=title::][fps=fps::]input ...]
	The input segments to concatenate together.
	Expected to be the same dimensions.
	These can be prefixed with '::' delimited arguments
		title
		fps
	example:
		title=firstvid::fps=25::some/path/to/directory/of/images
	This allows specifying the input fps of a directory of images which
	would otherwise be defaulted to 25 fps.
"

	# parse arguments
	local OWIDTH= OHEIGHT=
	local FPS=
	local GOP=default
	local IFPS=()
	local INPUTS=()
	local IEXTRA=()
	local XEXTRA=()
	local TITLES=()
	local ISDIR=()
	local NUMBER=0
	local TITLECARD=
	local OUT=out.mp4
	local OFLAGS=(-c:v libx264 -profile:v high -pix_fmt yuv420p)
	while ((${#}))
	do
		case "${1}" in
			-s|--size)
				shift
				OHEIGHT="${1#*x}"
				OWIDTH="${1%x*}"
				;;
			-n|--number_frames)
				NUMBER=1
				;;
			-g|--gop)
				shift
				GOP="${1}"
				;;
			-f|--fps)
				shift
				FPS="${1}"
				;;
			--oflags)
				shift
				OFLAGS=("${@}")
				break
				;;
			-o|--out)
				shift
				OUT="${1}"
				;;
			-h|--help)
				echo "${HELP_MSG}"
				return 1
				;;
			-t|--title)
				if [[ "${2}" =~ -.* ]]
				then
					TITLECARD=3
				else
					shift
					TITLECARD="${1}"
				fi
				;;
			*)
				iname="${1}"
				local title= fps= arg extra_args=()
				while [[ "${iname}" =~ .*::.* ]]
				do
					arg="${iname%%::*}"
					iname="${iname#*::}"
					case "${arg}" in
						fps=*)
							fps="${arg#fps=}"
							;;
						title=*)
							title="${arg#title=}"
							;;
						*=*)
							extra_args+=("-${arg%%=*}")
							if [[ -n "${arg#*=}" ]]
							then
								extra_args+=("${arg#*=}")
							fi
							;;
						*)
							title="${arg}"
							;;
					esac
				done
				XEXTRA+=("${#IEXTRA[@]}" "${#extra_args[@]}")
				IEXTRA+=("${extra_args[@]}")

				local iname="$(realpath "${iname}")"
				if [[ -d "${iname}" ]]
				then
					local fnames=("${iname}"/*) pattern npre nsuf title
					get_pattern fnames iname npre nsuf
					if ! ((nsuf))
					then
						echo "Bad directory input: detected pattern has no suffix." >&2
						echo "  pattern: \"${iname}\"" >&2
						echo "  prefix: \"${iname:0:npre}\"" >&2
						echo "  suffix: \"${iname:${#iname}-nsuf:nsuf}\"" >&2
						return 1
					fi
					ISDIR+=(1)
				else
					ISDIR+=(0)
				fi
				INPUTS+=("${iname}")
				IFPS+=("${fps}")
				if [[ -z "${title}" ]]
				then
					guess_name "${iname}" "Segment ${#INPUTS[@]}" title
				fi
				TITLES+=("${title}")
				;;
		esac
		shift
	done

	# gather input info
	local RFPS=() AFPS=() WIDTH=() HEIGHT=()
	gather_info INPUTS RFPS AFPS WIDTH HEIGHT

	# Calculate input fps
	idx=0
	while ((idx < "${#INPUTS[@]}"))
	do
		if [[ -z "${IFPS[idx]}" ]]
		then
			if [[ "${AFPS[idx]}" != "${RFPS[idx]}" ]]
			then
				echo "WARNING: \"${INPUT[idx]}\" real and average fps differ" >&2
				echo "avg_frame_rate: ${AFPS[idx]}" >&2
				echo "r_frame_rate  : ${RFPS[idx]}" >&2
			fi
			IFPS[idx]="${AFPS[idx]}"
		fi
		((++idx))
	done

	printf 'inputs:\n'
	local idx=0
	while ((idx < ${#INPUTS[@]}))
	do
		echo "${INPUTS[idx]}"
		echo "  extra : ${IEXTRA[@]:XEXTRA[idx*2]:XEXTRA[idx*2 + 1]}"
		echo "  title : \"${TITLES[idx]}\""
		echo "  width : ${WIDTH[idx]}"
		echo "  height: ${HEIGHT[idx]}"
		echo "  fps   : ${IFPS[idx]}"
		echo "  imdir : ${ISDIR[idx]}"
		((++idx))
	done

	# calculate output shape
	if [[ -z "${OWIDTH}" ]]
	then
		calc_max WIDTH OWIDTH
	fi
	if [[ -z "${OHEIGHT}" ]]
	then
		calc_max HEIGHT OHEIGHT
	fi
	echo "output width: ${OWIDTH}"
	echo "output height: ${OHEIGHT}"

	# calculate output fps
	if [[ -z "${FPS}" ]]
	then
		if [[ $(printf '%s\n' "${IFPS[@]}" | sort | uniq | wc -l) -gt 1 ]]
		then
			echo "Conflicting detected fps.  Please use -f flag to set output fps."
			return 1
		else
			FPS="${IFPS[0]}"
		fi
	fi

	# generate commandline
	local FFIN=()
	local FILTERGRAPH=
	local CONCATSRC=
	local ffidx=0 inidx=0
	while ((inidx < ${#INPUTS[@]}))
	do
		if [[ -n "${TITLECARD}" ]]
		then
			FFIN+=(-f lavfi -r "${FPS}" -t ${TITLECARD} -i "color=white:${OWIDTH}x${OHEIGHT}")
			FILTERGRAPH="${FILTERGRAPH:+${FILTERGRAPH};}[${ffidx}:v:0]drawtext=fontsize=32:text=${TITLES[inidx]}:x=(w-tw)/2:y=(h-lh)/2[filt${ffidx}]"
			CONCATSRC="${CONCATSRC}[filt${ffidx}]"
			((++ffidx))
		fi
		FFIN+=("${IEXTRA[@]:XEXTRA[inidx*2]:XEXTRA[inidx*2 + 1]}" -i "${INPUTS[inidx]}")
		if ((NUMBER || WIDTH[inidx] != OWIDTH || HEIGHT[inidx] != OHEIGHT))
		then
			local curfilt=
			# draw frame number
			if ((NUMBER))
			then
				curfilt+="drawtext=fontsize=32:box=1:boxborderw=5:text=frame %{n}:x=5:y=5"
			fi
			# pad to larger dims
			if ((WIDTH[inidx] < OWIDTH || HEIGHT[inidx] < OHEIGHT))
			then
				local padargs=
				if ((WIDTH[inidx] < OWIDTH))
				then
					padargs+="w=${OWIDTH}"
				fi
				if ((HEIGHT[inidx] < OHEIGHT))
				then
					padargs+="${padargs:+:}h=${OHEIGHT}"
				fi
				curfilt+="${curfilt:+,}pad=color=black:${padargs}"
			fi
			# crop to smaller size
			if ((WIDTH[inidx] > OWIDTH || HEIGHT[inidx] > OHEIGHT))
			then
				local cropargs=
				if ((WIDTH[inidx] > OWIDTH))
				then
					cropargs+="w=${OWIDTH}"
				fi
				if ((HEIGHT[inidx] > OHEIGHT))
				then
					cropargs+="${cropargs:+:}h=${OHEIGHT}"
				fi
				curfilt+="${curfilt:+,}crop=${cropargs}"
			fi
			FILTERGRAPH+="${FILTERGRAPH:+;}[${ffidx}:v:0]${curfilt}[filt${ffidx}]"
			CONCATSRC+="[filt${ffidx}]"
		else
			CONCATSRC+="[${ffidx}:v:0]"
		fi
		((++ffidx))
		((++inidx))
	done

	if [[ -z "${GOP}" || "${GOP}" = '0' ]]
	then
		GOP=()
	elif [[ "${GOP}" = 'default' ]]
	then
		GOP=(-g "${FPS}")
	else
		GOP=(-g "${GOP}")
	fi


	set -x
	ffmpeg "${FFIN[@]}" \
		-filter_complex "${FILTERGRAPH:+${FILTERGRAPH};}${CONCATSRC}concat=n=${ffidx}:v=1:a=0[catted]" \
		-map '[catted]' -r "${FPS}" "${GOP[@]}" "${OFLAGS[@]}" "${OUT}"
	set +x
}
run "${@}"
