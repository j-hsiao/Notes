#!/bin/bash

dnames=(
	"${XDG_RUNTIME_DIR}"
	${XDG_RUNTIME_DIR}/pulse
)

wayland="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
pulse="${XDG_RUNTIME_DIR}/pulse/native"

fnames=(
	"${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
	"${XDG_RUNTIME_DIR}/pulse/native"
)

username="${1:-${USER}_}"

chmod 770 "${dnames[@]}"
chmod 775 "${fnames[@]}"
chown "${USER}:${username}" "${dnames[@]}" "${fnames[@]}"


machinectl shell \
	--setenv=XDG_SESSION_TYPE \
	--setenv=WAYLAND_DISPLAY="${wayland}" \
	--setenv=XAUTHORITY \
	--setenv=PULSE_SERVER="unix:${pulse}" \
	"${username}"@

chmod 700 "${dnames[@]}"
chmod 755 "${fnames[@]}"
chown "${USER}:${USER}" "${dnames[@]}" "${fnames[@]}"
