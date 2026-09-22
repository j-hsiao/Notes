#!/bin/bash

# Wrap ssh in a function.
# If no command, then use tmux as the command and add -t if not already present.
# Looking at man page, flags can either have 0 or 1 arg, so grep man seems to show
# which flags have an arg:
# 	man ssh | grep '^[[:blank:]]*-[^[:blank:]] [^[:blank:]]' \
# 		| tr -s ' ' | cut -d' ' -f 2 | sort | uniq | paste -s -d'|'
ssh() {
	local args=("${@}")
	local npos=0 termarg=-t
	for ((idx=0; idx<"${#args[@]}"; ++idx))
	do
		case "${args[idx]}" in
			-B|-D|-E|-F|-I|-J|-L|-O|-Q|-R|-S|-W|-b|-c|-e|-i|-l|-m|-o|-p|-w)
				((++idx));;
			-t)
				termarg=;;
			-*)
				:;;
			*)
				if ((++npos >= 2))
				then
					command ssh "${args[@]}"
					return
				fi
		esac
	done
	command ssh "${args[@]}" ${termarg} 'tmux -S "${XDG_RUNTIME_DIR:-${HOME}}'"/.tmux-${USER}"'" new -A'
}
