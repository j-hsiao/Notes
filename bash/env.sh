#!/bin/bash
# setup my preferred bash environment

ROOTDIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

redirect_cmd() {
	dst="${1}"
	shift
	if [[ -n "${DRYRUN}" ]]
	then
		echo "${@}" \>\> "${dst}"
	else
		"${@}" >> "${dst}"
	fi
}

setup_vim() {
	local vimdir
	vimdir="${ROOTDIR}/../editors/vim"
	redirect_cmd "${HOME}/.vimrc" cat "${vimdir}/.vimrc"
	${DRYRUN:+echo} bash "${vimdir}/makeft.sh"
	local loc
	for loc in 'autoload' plugin
	do
		if [[ ! -d "${HOME}/.vim/${loc}" ]]
		then
			${DRYRUN:+echo} mkdir -p "${HOME}/.vim/${loc}"
		fi
		local f
		for f in "${vimdir}/vim/${loc}"/*
		do
			${DRYRUN:+echo} "${CREATE[@]}" "${f}" "${HOME}/.vim/${loc}"
		done
	done
}

setup_readline() {
	redirect_cmd "${HOME}/.inputrc" cat "${ROOTDIR}/../readline/inputrc"
}

setup_bash() {
	local scriptdirs=()
	local d=
	for d in "${HOME}/scripts" "${HOME}/.scripts"
	do
		if [[ -d "${d}" ]]
		then
			scriptdirs+=("${d}")
		fi
	done
	if grep 'microsoft.*WSL' < <(uname -a) &>/dev/null
	then
		scriptdirs+=("${ROOTDIR}/wsl")
	fi

	if ! grep 'notes/bash/scripts/load.sh' "${HOME}/.bashrc" &>/dev/null || [[ -n "${DRYRUN}" ]]
	then
		printf '%s\n' ". \"${ROOTDIR}/scripts/load.sh\" \\" "" "${scriptdirs[@]}" \
			| ${DRYRUN:-redirect_cmd "${HOME}/.bashrc"} sed '2,$s/\(.*\)/\t'\''\1'\'' \\/'
	fi
}



run_setup_env() {
	DRYRUN=''
	CREATE=(ln -s)

	while ((${#}))
	do
		case "${1}" in
			-d|--dryrun)
				DRYRUN=' '
				;;
			-c|--create)
				CREATE="${@}"
				break
				;;
			*)
				;;
		esac
		shift
	done

	for func in setup_vim setup_readline setup_bash
	do
		if [[ -n "${DRYRUN}" ]]
		then
			printf '______________________________\n%s\n------------------------------\n' "${func}"
		fi
		"${func}"
	done
}


run_setup_env "${@}"
