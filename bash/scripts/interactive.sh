#!/bin/bash
# If bash is run as an interactive shell

if [[ "${-}" = *i* ]]
then
	# aliases to reduce accidental ovewriting.
	alias rm='rm -i'
	alias cp='cp -i'
	alias mv='mv -i'

	# custom PS1 settings
	if [[ "${TERM}" = @(xterm-color|*-256color) || "${COLORTERM}" = *color* ]] \
		|| { hash tput &>/dev/null && tput setaf 1 &>/dev/null; }
	then
		PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
	else
		PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
	fi
	case "$TERM" in
		xterm*|rxvt*)
			PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1";;
	esac
fi
