#!/bin/bash


share() {
	local username="${1:-${USER}_}"
	xhost "+si:localuser:${username}"
	sudo machinectl shell \
		--setenv=XDG_SESSION_TYPE=x11 \
		--setenv=DISPLAY \
		--setenv=MOZ_ENABLE_WAYLAND=0 \
		--setenv=MOZ_DISABLE_WAYLAND=1 \
		--setenv=PULSE_SERVER=tcp:4713 \
		"${username}@"
}

vncsub() {
	local username="${1:-${USER}_}"
	local item
	local largest=0
	for item in /tmp/.X11-unix/*
	do
		echo "checking item ${item}"
		if ((largest < "${item##*X}"))
		then
			largest="${item##*X}"
		fi
	done
	((++largest))
	echo "Running display :${largest}"

	local passwd="${HOME}/.config/tigervnc/passwd"
	Xvnc -geometry 1700x1440 -rfbauth "${passwd}" :"${largest}" -localhost -NeverShared &>/dev/null &
	local vncpid=$!
	xfwm4 --display ":${largest}" &>/dev/null &
	local xfwmpid=$!
	sleep 2
	vncviewer -passwd "${passwd}" ":${largest}" &>/dev/null &
	local vncviewerpid=$!

	sudo machinectl shell \
		--setenv=XDG_SESSION_TYPE=x11 \
		--setenv=WAYLAND_DISPLAY= \
		--setenv=DISPLAY=":${largest}" \
		--setenv=MOZ_ENABLE_WAYLAND=0 \
		--setenv=MOZ_DISABLE_WAYLAND=1 \
		"${username}@"
	kill "${vncviewerpid}" "${xfwmpid}" "${vncpid}"
}
