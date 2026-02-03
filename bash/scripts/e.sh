#!/bin/bash

# Activate python envs with tab completion.

PYTHON_ENVS_DIR="${PYTHON_ENVS_DIR:-${HOME}/.pyenv/versions}"

e() {
	if [[ -f "${1}/bin/activate" ]]
	then
		. "${1}/bin/activate"
	else
		# windows python env usually has \r\n in the
		# script file which causes issues for bash.
		. <(tr -d '\r' < "${1}/Scripts/activate")
	fi
}

_e_completer()
{
	if [[ "${BASHOPTS}" != *nullglob* ]]
	then
		shopt -s nullglob
		trap 'shopt -u nullglob; trap - RETURN' RETURN
	fi
	local word="${2}"
	local choice=
	if [[ "${word}" =~ ^(.*),([0-9]*)$ ]]
	then
		word="${BASH_REMATCH[1]}"
		choice="${BASH_REMATCH[2]}"
	fi
	case "${word}" in
		*/*) COMPREPLY=("${word}"*/);;
		.) COMPREPLY=(./*/);;
		*)
			local envnames=(
				"${PYTHON_ENVS_DIR[@]}"
				"${HOME}/.pyenv/versions"
				"${PYENV_ROOT}/versions"
				"${HOME}/envs"
				"${HOME}/.envs"
			)
			local end="${#envnames[@]}"
			local start
			local idx
			for ((start=0; start<end; ++start))
			do
				for ((idx=start+1; idx<end; ++idx))
				do
					if [[ "${envnames[start]}" = "${envnames[idx]}" ]]
					then
						envnames[idx]="${envnames[end-1]}"
						unset envnames[--end]
					fi
				done
			done
			COMPREPLY=()
			for ((idx=0; idx<${#envnames[@]}; ++idx))
			do
				if [[ -d "${envnames[idx]}" ]]
				then
					COMPREPLY+=("${envnames[idx]}/${word}"*)
				fi
			done
			;;
	esac
	COMPREPLY=("${COMPREPLY[@]%/}")
	if [[ -n "${choice}" ]]
	then
		COMPREPLY=("${COMPREPLY[choice]}")
	elif (("${#COMPREPLY[@]}" > 1))
	then
		local prefix="${#COMPREPLY[0]}"
		local idx cand
		for ((cand=1; cand<"${#COMPREPLY[@]}"; ++cand))
		do
			for ((idx=0; idx<prefix; ++idx))
			do
				if [[ "${COMPREPLY[0]:idx:1}" != "${COMPREPLY[cand]:idx:1}" ]]
				then
					prefix="${idx}"
					break
				fi
			done
		done
		if [[ "${COMPREPLY[*]:prefix}" != */* ]]
		then
			# All from the same directory
			COMPREPLY=("${COMPREPLY[@]##*/}")
		fi
		local fmt="${#COMPREPLY[@]}"
		fmt="\\n%${#fmt}d: %s"
		for ((idx=0; idx<${#COMPREPLY[@]}; ++idx))
		do
			printf "${fmt}" "${idx}" "${COMPREPLY[idx]%/}"
		done
		COMPREPLY=('' ' ')
	fi
}
complete -o filenames -o dirnames -F _e_completer e
