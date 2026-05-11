#!/bin/bash

g()
{
	# Set remote g to the original repo's origin remote
	local verbose=:
	local start="${PWD}"
	trap 'trap - RETURN; cd "${start}"' RETURN
	while (($#))
	do
		case "${1}" in
			-v|--verbose) verbose=;;
			-h|--help)
				local msg='g [-v] [repo=${PWD}]
				Follow the "origin" remote until "origin" either points to a non-local repo
				or it points to a repo that does not have an "origin" remote.  Set "g" remote
				to this repo.

				-v: verbose
				repo: the repo to set the "g" remote
				'
				echo "${msg//$'\t'}" >&2
				return
				;;
			*)
				if [[ -d "${1}" ]]
				then
					cd "${1}" || return 1
				else
					echo "Unknown argument: $1" >&2
					return 1
				fi
				;;
		esac
		shift
	done
	local root="${PWD}"
	local remote
	remote="$(git remote get-url origin)" || return
	while [[ -d "${remote}" ]]
	do
		${verbose} echo "${PWD} -> ${remote}" >&2
		cd "${remote}"
		local nxt=
		if nxt="$(git remote get-url origin 2>/dev/null)"
		then
			remote="${nxt}"
		else
			remote="${PWD}"
			${verbose} echo "Current dir: ${PWD}" >&2
			${verbose} echo "remotes:" >&2
			${verbose} git remote -v >&2
			cd "${OLDPWD}"
			break
		fi
	done
	local premote="$(git remote get-url origin --push)"
	cd "${root}"
	${verbose} echo "remote: ${remote}" >&2
	${verbose} echo "push  : ${premote}" >&2

	local remotes="$(git remote -v)"
	if [[ "${remotes}" != *${remote}* ]]
	then
		git remote add g "${remote}" || return
		if [[ "${premote}" != "${remote}" ]]
		then
			git remote set-url g --push "${premote}"
		fi
	else
		local exist="${remotes%%"${remote}"*}"
		printf 'Remote target exists:\n%s\n' "${exist##*$'\n'}${remote}" >&2
	fi
}
