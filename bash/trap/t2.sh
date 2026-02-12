#!/bin/bash

fun() # command script
{
	trap return ERR
	trap 'trap - ERR RETURN' RETURN
	trap -p ERR RETURN
	echo 'outside before'
	. "${2:-"${BASH_SOURCE[0]%t2.sh}t3.sh"}" "${1:-false}"
	echo "outside after errorcode: $?"
	trap -p ERR RETURN
	echo 'outside finish'
}

fun() # command script
{
	trap return ERR
	trap 'trap - ERR RETURN' RETURN
	trap -p ERR RETURN
	echo 'outside before'
	. "${2:-"${BASH_SOURCE[0]%t2.sh}t3.sh"}" "${1:-false}" || return
	echo "outside after errorcode: $?"
	trap -p ERR RETURN
	echo 'outside finish'
}

fun "${@}"
