#!/bin/bash

# wsl /tmp/.X11-unix/ is mounted as read-only.
# However, vncserver requires write-access to /tmp/.X11-unix.
# Don't remember the source link, but /mnt/wslg/.X11-unix/X0 has the
# same inode as /tmp/.X11-unix/X0 so can just remount /tmp/.X11-unix
# as writeable, and then symlink
#
# Other observations:
# ls -i /mnt/wslg/run/user/${EUID}/ ${XDG_RUNTIME_DIR}
# shows identical entries, each with the same inode
# In fact, creating a file in ${XDG_RUNTIME_DIR} seems to create the same
# file with same inode under /mnt/wslg/run/user/${EUID} as well
#
# everything in /mnt/wslg/runtime-dir/ seems to have symlink counterparts
# in ${XDG_RUNTIME_DIR}

noway()
{
	# Disable wayland socket in ${XDG_RUNTIME_DIR}
	if [[ "${BASHOPTS}" != *'nullglob'* ]]
	then
		shopt -s nullglob
		trap 'trap - RETURN; shopt -u nullglob' RETURN
	fi

	local targets=("${XDG_RUNTIME_DIR:-"/run/user/${EUID}"}/wayland"*)
	if ((${#targets[@]}))
	then
		for item in "${targets[@]}"
		do
			if ! [[ -h "${item}" && "$(readlink "${item}")" = "/mnt/wslg/runtime-dir/${item##*/}" ]]
			then
				echo "Unexpected item ${item}" >&2
				return 1
			fi
		done
		command rm "${targets[@]}"
	fi
}

wsl__ensure_symlink() # src dst
{
	if [[ ! -e "${2}" ]]
	then
		ln -s "${1}" "${2}"
	elif [[ -h "${2}" ]]
	then
		if [[ "$(readlink -f "${2}")" != "${1}" ]]
		then
			printf '%s\n' \
				"WARNING: symlink ${2} exists but different source:" \
				"  current : $(readlink -f "${2}")" \
				"  expected: ${1}" >&2
		fi
	else
		echo "WARNING: ${2} exists but is not as expected." >&2
	fi
}

way()
{
	# reenable wayland socket in ${XDG_RUNTIME_DIR}
	if [[ "${BASHOPTS}" != *'nullglob'* ]]
	then
		shopt -s nullglob
		trap 'trap - RETURN; shopt -u nullglob' RETURN
	fi
	local targets=("/mnt/wslg/runtime-dir/wayland"*)
	for item in "${targets[@]}"
	do
		wsl__ensure_symlink "${item}" "${XDG_RUNTIME_DIR:-"/run/user/${EUID}"}/${item##*/}"
	done
}

vncprep()
{
	if [[ ! -h /tmp/.X11-unix/X0 ]]
	then
		[[ "${USER}" != root ]] && local sudo=sudo || local sudo=
		${sudo} mount tmpfs -t tmpfs /tmp/.X11-unix -o size=1M
		${sudo} chmod 1777 /tmp/.X11-unix
		local item
		if [[ "${BASHOPTS}" != *'nullglob'* ]]
		then
			shopt -s nullglob
			trap 'trap - RETURN; shopt -u nullglob' RETURN
		fi
		for item in /mnt/wslg/.X11-unix/*
		do
			wsl__ensure_symlink "${item}" "${item/*wslg/"/tmp"}"
		done
	fi
}

vncserver()
{
	vncprep
	noway
	command vncserver "${@}"
}
