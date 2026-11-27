#!/bin/bash

gitalias() {
	# interact with next child commit
	local next='next=$(git rev-list --ancestry-path --topo-order --all ^@); next="${next##*$'\''\n'\''}"'
	local diffnext="${next}"'; if [[ -n "${next}" ]]; then git diff @ "${next}"; fi'
	local mergenext="${next}"'; if [[ -n "${next}" ]]; then git merge "${next}"; fi'
	local lognext="${next}"'; if [[ -n "${next}" ]]; then git log -1 "${next}"; fi'

	git config "${@:---local}" alias.ndiff '!'"bash -c '${diffnext//\'/\'\\\'\'}'"
	git config "${@:---local}" alias.nmerge '!'"bash -c '${mergenext//\'/\'\\\'\'}'"
	git config "${@:---local}" alias.nlog '!'"bash -c '${lognext//\'/\'\\\'\'}'"

	# visual log of all commits
	git config "${@:---local}" alias.vlog 'log --all --oneline --decorate --graph'
}
