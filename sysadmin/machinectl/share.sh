#!/bin/bash

username="${USER}_"
cmd=()
while (($#))
do
	case "${1}" in
		-u)
			shift
			username="${1}"
			;;
		-h|--help)
			echo 'usage: bash share.sh [-h] [-u user] [program [args...]]
			[-u user]
			    Specify the user, defaults to ${USER}_
			[-h|--help]
			    Print this help message
			[program [args...]]
			    Run the given program.  Otherwise opens the default
			    shell for the specified user.
			' | sed 's/\t*//g'
			exit
			;;
		*)
			cmd+=("$(which "${1}")") || exit
			shift
			cmd+=("${@}")
			break
			;;
	esac
	shift
done


dnames=(
	"${XDG_RUNTIME_DIR}"
	${XDG_RUNTIME_DIR}/pulse
)

wayland="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
pulse="${XDG_RUNTIME_DIR}/pulse/native"

fnames=(
	"${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
	"${XDG_RUNTIME_DIR}/pulse/native"
	"${XDG_RUNTIME_DIR}/pipewire-0"
)




chmod 710 "${dnames[@]}"
chmod 775 "${fnames[@]}"
chown "${USER}:${username}" "${dnames[@]}" "${fnames[@]}"


machinectl shell \
	--setenv=XDG_SESSION_TYPE \
	--setenv=WAYLAND_DISPLAY="${wayland}" \
	--setenv=XAUTHORITY \
	--setenv=PULSE_SERVER="unix:${pulse}" \
	--setenv=DISPLAY \
	"${username}"@ "${cmd[@]}"

chmod 700 "${dnames[@]}"
chmod 755 "${fnames[@]}"
chown "${USER}:${USER}" "${dnames[@]}" "${fnames[@]}"
