#!/bin/bash

# With mouse acceleration, it seems like movement by 1 pixel
# is the only accurate movement.

ydoreset()
{
	ydomove 0,1440
	ydomove -2560,0
	ydomove 100,0
	ydomove 0,-1440
	ydomove 0,100
	export YDOX=100
	export YDOY=100
}

ydomove()
{
	# ydo mouse move while tracking mouse position.
	local abs=0
	local incr=0
	local x=0
	local y=0
	while (($#))
	do
		case "${1}" in
			-a)
				abs=1
				;;
			-i)
				incr=1
				;;
			*,*)
				x="${1%%,*}"
				y="${1##*,}"
				;;
			*)
				if [[ "${1}" =~ [0-9]* && "${2}" =~ [0-9]* ]]
				then
					x="${1}"
					y="${2}"
					shift
				else
					echo "Unrecognized argument: \"${1}\""
				fi
		esac
		shift
	done

	if ((abs))
	then
		echo "YDOX is ${YDOX}"
		if [[ -z "${YDOX}" ]]
		then
			echo 'YDO not initialized!'
			return 1
		fi
		ydomove $((x-YDOX)),$((y-YDOY))
	else
		if ((incr))
		then
			local xstep=$((x > 0 ? -1 : 1))
			local ystep=$((y > 0 ? -1 : 1))
			while ((x || y))
			do
				ydotool mousemove \
					-x $((x > 0 ? 1 : x < 0 ? -1 : 0)) \
					-y $((y > 0 ? 1 : y < 0 ? -1 : 0))
				((x += x ? xstep : 0))
				((y += y ? ystep : 0))
			done
		else
			ydotool mousemove -x "${x}" -y "${y}"
		fi
		((YDOX+=x))
		((YDOY+=y))
		((YDOX < 0 ? 0 : YDOX))
		((YDOY < 0 ? 0 : YDOY))
	fi
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	cmd=()
	export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-"/dev/shm/${USER}_ydo.sock"}"
	daemon=0
	while (($#))
	do
		case "${1}" in
			-h|--help)
				echo 'bash '"${BASH_SOURCE[0]}"' [-h] [-p] command
				[-h|--help]
				    print this message
				[-p sock]
				    Specify the ydotoold socket path'
				;;
			-p)
				shift
				export YDOTOOL_SOCKET="${1}"
				;;
			-d)
				daemon=1
				;;
			*)
				cmd=("${@}")
				break
		esac
		shift
	done
	if [[ "${USER}" != 'root' ]]
	then
		original=$(gsettings get org.gnome.desktop.peripherals.mouse accel-profile)
		gsettings set org.gnome.desktop.peripherals.mouse accel-profile "'flat'"
		if [[ "${original}" != 'flat' ]]
		then
			trap "gsettings set org.gnome.desktop.peripherals.mouse accel-profile \"${original}\"" SIGINT EXIT
		fi
		sudo bash "${BASH_SOURCE[0]}" -p "${YDOTOOL_SOCKET}" "${@}"
		if [[ "${original}" != 'flat' ]]
		then
			gsettings set org.gnome.desktop.peripherals.mouse accel-profile "${original}"
			trap - SIGINT EXIT
		fi
	else
		if ((daemon))
		then
			ydotoold -p "${YDOTOOL_SOCKET}" &
			ydotooldpid=$!
			trap "kill ${ydotooldpid}; rm \"${YDOTOOL_SOCKET}\"" EXIT
			sleep 1
			ydoreset
		fi

		"${@}"

		if ((daemon))
		then
			kill "${ydotooldpid}"
			rm "${YDOTOOL_SOCKET}"
			trap - EXIT
		fi
	fi
fi
