#!/bin/bash

g()
{
	local orig="${PWD}"
	local remote="$(git remote get-url origin)"
	while [[ -d "${remote}" ]]
	do
		cd "${remote}"
		remote="$(git remote get-url origin)"
	done
	local premote="$(git remote get-url origin --push)"
	cd "${orig}"
	git remote add g "${remote}"
	if [[ "${premote}" != "${remote}" ]]
	then
		git remote set-url g --push "${premote}"
	fi
}
