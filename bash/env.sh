#!/bin/bash
# setup my preferred bash environment

ROOTDIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

capp() {
	# capp <src> <target> [trim]
	# Conditionally append text to the target file.
	#
	# If the target file already contains text (verbatim)
	# then do nothing.  Otherwise append to the file.
	#
	# If trim is provided, then remove it from end of <text>.
	# This is useful if the input is from a command substitution
	# and trailing newlines should be preserved.
	local text="${1}"
	local target="${2}"
	local trim="${3}"

	if [[ -n "${trim}" ]]
	then
		text="${text%"${trim}"}"
	fi

	local current="$(cat "${target}")"
	if [[ "${current#*"${text}"}" = "${current}" ]]
	then
		if [[ -n "${DRYRUN}" ]]
		then
			if ((${#text} > 70))
			then
				printf 'Would add:\n%s...%s\nto "%s"\n' "${text:0:35}" "${text:${#text}-35}" "${target}"
			else
				printf 'Would add:\n%s\nto "%s"\n' "${text}" "${target}"
			fi
		else
			printf '%s\n' "${text}" >> "${target}"
		fi
		return 0
	else
		echo "${target} already contains text, ignoring."
		return 1
	fi
}

ccat() {
	# ccat <src> <target>
	# Similar to capp, except src is a file instead of text.
	# If target does not already exist, then use "${CREATE[@]}" to create it from src
	# Otherwise, equivalent to capp "$(cat src)" <target>
	local src="${1}"
	local target="${2}"
	if [[ -f "${target}" ]]
	then
		capp "$(cat "${src}")" "${target}"
	else
		${DRYRUN:+echo} "${CREATE[@]}" "${src}" "${target}"
	fi
}

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
	ccat "${vimdir}/.vimrc" "${HOME}/.vimrc"
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
			local target="${HOME}/.vim/${loc}/${f##*/}"
			if [[ ! -e "${target}" ]]
			then
				${DRYRUN:+echo} "${CREATE[@]}" "${f}" "${target}"
			elif [[ -n "${DRYRUN}" ]]
			then
				echo "${target} already exists"
			fi
		done
	done
}

setup_readline() {
	ccat "${ROOTDIR}/../readline/inputrc" "${HOME}/.inputrc"
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

	capp "$(printf '%s\n' ". \"${ROOTDIR}/scripts/load.sh\" \\" "" "${scriptdirs[@]}" \
		| sed '2,$s/\(.*\)/\t'\''\1'\'' \\/')" "${HOME}/.bashrc"
}



run_setup_env() {
	local DRYRUN=''
	local CREATE=(ln -s)

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
			-h|--help)
				echo "${BASH_SOURCE[0]} [-d] [-c ...] [-h]

[-d|--dryrun]
Only print what would happen, do not actually make any changes.

[-c|--create] [args...]
The command to use when creating a new file.  Suggestions are:
ln -s (default)
ln -i
cp -i

[-h|--help]
Display this help message
"
				return
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
