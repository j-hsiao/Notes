#!/bin/bash

dnames=("${XDG_RUNTIME_DIR}")
fnames=("${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}")

username="${1:-${USER}_}"

chmod 770 "${dnames[@]}"
chmod 775 "${fnames[@]}"
sudo chown "${USER}:${username}" "${dnames[@]}" "${fnames[@]}"


machinectl shell \
	--setenv=XDG_SESSION_TYPE \
	--setenv=WAYLAND_DISPLAY="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" \
	--setenv=XAUTHORITY \
	"${username}"@

chmod 700 "${dnames[@]}"
chmod 755 "${fnames[@]}"
chown "${USER}:${USER}" "${dnames[@]}" "${fnames[@]}"
