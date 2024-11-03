#!/bin/bash

# load scripts in the containing directory

if ! declare -f load_dir_scripts &>/dev/null
then
	load_dir_scripts()
	{
		local dname f
		for dname in "${@}"
		do
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
