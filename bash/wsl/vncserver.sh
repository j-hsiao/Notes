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
		rm "${targets[@]}"
	fi
}

wsl__ensure_symlink() # src dst
{
	if [[ ! -e "${dst}" ]]
	then
		ln -s "${src}" "${dst}"
	elif [[ -h "${dst}" ]]
	then
		if [[ "$(readlink -f "${dst}")" != "${src}" ]]
		then
			printf '%s\n' \
				"WARNING: symlink ${dst} exists but different source:" \
				"  current : $(readlink -f "${dst}")" \
				"  expected: ${item}" >&2
		fi
	else
		echo "WARNING: ${dst} exists but is not as expected." >&2
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
	if mountpoint /tmp/.X11-unix
	then
		if [[ "${USER}" != root ]]
		then
			local sudo=sudo
		else
			local sudo=
		fi
		${sudo} umount /tmp/.X11-unix
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
