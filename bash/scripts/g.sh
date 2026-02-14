#!/bin/bash

g()
{
	# Set remote g to the original repo's origin remote
	local orig="${PWD}"
	local remote
	remote="$(git remote get-url origin)" || return
	while [[ -d "${remote}" ]]
	do
		cd "${remote}"
		remote="$(git remote get-url origin)" || return
	done
	local premote="$(git remote get-url origin --push)"
	cd "${orig}"

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
		printf 'Remote target exists:\n%s\n' "${exist##*$'\n'}${remote}"
	fi
}
