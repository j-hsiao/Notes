#!/bin/bash
# setup my preferred bash environment

ROOTDIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

findch() # <text> <char> [out=RESULT] [start=0]
{
	# Find char in text.
	local fch__idx=$((${4:-0}-1))
	local -n fch__out="${3:-RESULT}"
	while ((++fch__idx < ${#1}))
	do
		if [[ "${1:fch__idx:1}" = "${2}" ]]
		then
			fch__out="${fch__idx}"
			return
		fi
	done
	fch__out=-1
}

split() # <text> [out=RESULT] [delim=$'\n']
{
	# split <text> into lines by [delim] and append to [out]
	local -n splt__out="${2:-RESULT}"
	local start=0 delim="${3:-$'\n'}" stop

	findch "${1}" "${delim}" stop "${start}"
	while ((stop >= 0))
	do
		splt__out[${#splt__out[@]}]="${1:start:stop-start}"
		((start = stop+1))
		findch "${1}" "${delim}" stop "${start}"
	done
	if ((start < ${#1}))
	then
		splt__out[${#splt__out[@]}]="${1:start}"
	fi
}

decadd() # <lines> <data> <dec> [trim]
{
	# Search through <lines> and remove lines wrapped by <dec>.
	# Add <data> at the end (with [trim] removed if applicable)
	# wrapped in <dec>.  <dec> should NOT contain new lines.
	local -n dcad__lines="${1}"
	local idx=-1 out=-1 inserting=0 didx=-1
	local datalines=()
	split "${2%"${4}"}" datalines

	while ((++idx < "${#dcad__lines[@]}"))
	do
		if [[ "${dcad__lines[idx]}" = "${3}" ]]
		then
			if ((inserting = ! inserting))
			then
				didx=0
				if ((idx != ++out))
				then
					dcad__lines[out]="${3}"
				fi
			else
				if ((didx < ${#datalines[@]}))
				then
					local remainder
					printf -v remainder '%s\n' "${datalines[@]:didx}"
					dcad__lines[++out]="${remainder}${3}"
				else
					if ((idx != ++out))
					then
						dcad__lines[out]="${3}"
					fi
				fi
			fi
			continue
		fi
		if ((inserting))
		then
			if ((didx < ${#datalines[@]}))
			then
				dcad__lines[++out]="${datalines[didx++]}"
			fi
		elif ((idx != ++out))
		then
			dcad__lines[out]="${dcad__lines[idx]}"
		fi
	done
	((idx=out++))
	while ((${#dcad__lines[@]} > out))
	do
		unset dcad__lines[++idx]
	done
	if ((didx < 0))
	then
		dcad__lines+=("${3}" "${datalines[@]}" "${3}")
	fi
}

replace_section() # <file> <data> <delimline> [isfile=0] ...
{
	# Replace anything within <delimline> in <file> with <data>
	# if [isfile], then <data> is actually a file path.
	# Multiple sets of <data> <delimline> [isfile] can be given
	# (In this case, isfile is required except for the last one)
	# though <delimline> should all be unique within a single call.
	local lines=()
	local target="${1}"
	readarray -t lines < "${target}"
	shift 1
	while ((${#}))
	do
		if ((${3:-0}))
		then
			local data="$(cat ${1} && echo x)"
			data="${data%x}"
			decadd lines "${data}" "${2}"
		else
			decadd lines "${1}" "${2}"
		fi
		shift 3
	done
	printf '%s\n' "${lines[@]}" > "${target}"
}

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
	vimdir="${ROOTDIR%/bash*}/editors/vim"

	${DRYRUN:+echo} replace_section "${HOME}/.vimrc" "${vimdir}/.vimrc" "\" ${vimdir}/.vimrc" 1
	${DRYRUN:+echo} bash "${vimdir}/makeft.sh"
	local loc
	for loc in 'autoload' 'plugin'
	do
		if [[ ! -d "${HOME}/.vim/${loc}" ]]
		then
			${DRYRUN:+echo} mkdir -p "${HOME}/.vim/${loc}"
		fi
		local src
		for src in "${vimdir}/vim/${loc}"/*
		do
			local target="${HOME}/.vim/${loc}/${src##*/}"
			if [[ ! -e "${target}" ]] || ! diff "${target}" "${src}"
			then
				${DRYRUN:+echo} "${CREATE[@]}" "${src}" "${target}"
				echo "Update script path: \"${target}\"."
			else
				echo "Exists and matches: \"${target}\"."
			fi
		done
	done
}

setup_readline() {
	local refpath="${ROOTDIR%/bash*}/readline/inputrc"
	${DRYRUN:+echo} replace_section "${HOME}/.inputrc" "${refpath}" "# ${refpath}" 1
}

setup_bash() {
	local scriptdirs=('')
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

	local idx=-1
	while ((++idx < ${#scriptdirs[@]}))
	do
		scriptdirs[idx]=$' \\\n\t'"\"${scriptdirs[idx]/#"${HOME}"/'${HOME}'}\""
	done

	if [[ -d "${HOME}/.pyenv/versions" ]]
	then
		local envsdir='${HOME}/.pyenv/versions'
	else
		local envsdir='${HOME}/envs'
	fi

	local data
	printf -v data '%s' ". \"${ROOTDIR/#"${HOME}"/'${HOME}'}/scripts/load.sh\"" "${scriptdirs[@]}" $'\n'
	${DRYRUN:+echo} replace_section "${HOME}/.bashrc" \
		"${data}" "# ${ROOTDIR}: scripts" 0 \
		"PYTHON_ENVS_DIR=\"${envsdir}\"" "# ${ROOTDIR}: e.sh" 0
}

run_setup_env() {
	local DRYRUN=''
	if [[ "$(uname -a)" =~ .*'CYGWIN'.* ]]
	then
		local CREATE=(cp)
	else
		local CREATE=(ln -s)
	fi

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

	local func
	while read func
	do
		func="${func##* }"
		if [[ "${func}" =~ ^'setup' ]]
		then
			if [[ -n "${DRYRUN}" ]]
			then
				printf '______________________________\n%s\n------------------------------\n' "${func}"
			fi
			"${func}"
		fi
	done < <(declare -F)
}

run_setup_env "${@}"
