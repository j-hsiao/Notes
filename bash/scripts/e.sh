#!/bin/bash

# Activate python envs with tab completion.

PYTHON_ENVS_DIR="${PYTHON_ENVS_DIR:-${HOME}/.pyenv/versions}"

. "${BASH_SOURCE[0]/%e.sh/util}/shoptstack.sh"

e() { . "${1}/bin/activate"; }

_e_completer()
{
	local word="${2}"
	[[ "${word}" =~ ^(.*[^/])//* ]] && word="${BASH_REMATCH[1]}"

	if [[ "${word}" =~ ^.*'/'.*$ ]]
	then
		return
	fi
	ss_push nullglob
	COMPREPLY=("${PYTHON_ENVS_DIR}/${2%/}"*)
	ss_pop
}
complete -o dirnames -F _e_completer e
