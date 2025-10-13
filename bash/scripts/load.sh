#!/bin/bash

# Define load_dir_scripts If this script is given args, then also call
# load_dir_scripts on those args.

if ! declare -f load_dir_scripts &>/dev/null
then
	# Source all the files in the given directories.
	# If a directory is the empty string, then source
	# the directory this function is defined in.
	load_dir_scripts()
	{
		local idx=0
		while ((++idx < ${#FUNCNAME[@]}))
		do
			[[ "${FUNCNAME[idx]}" = "${FUNCNAME[0]}" ]] && return
		done

		local dname f args=("${@}")
		# Shift args so they are not used by sourced files.
		shift "${#}"
		for dname in "${args[@]}"
		do
			if [[ -z "${dname}" ]]
			then
				if [[ -f "${BASH_SOURCE[0]}" ]]
				then
					dname="${BASH_SOURCE[0]%/*}"
					if [[ "${dname}" = "${BASH_SOURCE[0]}" ]]
					then
						dname='.'
					fi
				else
					continue
				fi
			fi
			if [[ ! -d "${dname}" ]]
			then
				continue
			fi
			for f in "${dname}"/*
			do
				if [[ -f "${f}" ]]
				then
					. "${f}"
				fi
			done
		done
	}
fi

load_dir_scripts "${@}"
