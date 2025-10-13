# e: Activate python envs with tab completion.

PYTHON_ENVS_DIR="${HOME}/envs"

e()
{
	. "${1}/bin/activate"
}

_e_completer()
{
	local word="${2}"
	[[ "${word}" =~ ^(.*[^/])//* ]] && word="${BASH_REMATCH[1]}"

	if [[ "${word}" =~ ^.*'/'.*$ ]]
	then
		return
	fi
	local unull=0
	if [[ ! "${BASHOPTS}" =~ ^.*:?nullglob:?.*$ ]]
	then
		shopt -s nullglob
		unull=1
	fi
	COMPREPLY=("${PYTHON_ENVS_DIR}/${2%/}"*)
	if ((unull))
	then
		shopt -u nullglob
	fi
}
complete -o dirnames -F _e_completer e

