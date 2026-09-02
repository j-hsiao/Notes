#!/bin/bash

# Ollama bash completions
# Also makes default command serve if no arguemnts

if [[ "${BASH_SOURCE[0]}" != /* ]]
then
	. "${PWD}/${BASH_SOURCE[0]}"
else
	ollama() {
		LD_LIBRARY_PATH="${BASH_SOURCE[0]%/*}/install/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
			"${BASH_SOURCE[0]%/*}/install/bin/ollama" "${@:-serve}"
	}

	_ollama_completer_() {
		COMPREPLY=()
		local candidate candidates=()
		local model_dir="${HOME}/.ollama/models/manifests/registry.ollama.ai/library"

		if [[ "${2}" = -* ]]
		then
			candidates=('-h' '--help' '--nowordwrap' '--verbose' '-v' '--version')
		else
			if [[ "${3}" = ollama || "${3}" = -* ]]; then
				candidates=('serve' 'create' 'show' 'run' 'stop' 'pull' 'push' 'signin' 'signout' 'list' 'ps' 'cp' 'rm' 'launch' 'help')
			elif [[ "${3}" = run ]]; then
				candidates=("${model_dir}"/*/*)
				candidates=("${candidates[@]#"${model_dir}/"}")
				candidates=("${candidates[@]/\//:}")
			elif [[ "${COMP_WORDS[COMP_CWORD]}" = : && "${COMP_WORDS[COMP_CWORD-2]}" = run ]]; then
				candidates=("${model_dir}/${COMP_WORDS[COMP_CWORD-1]}"/*)
				candidates=("${candidates[@]##*/}")
			elif [[ "${COMP_WORDS[COMP_CWORD-1]}" = : && "${COMP_WORDS[COMP_CWORD-3]}" = run ]]; then
				candidates=("${model_dir}/${COMP_WORDS[COMP_CWORD-2]}/${2}"*)
				candidates=("${candidates[@]##*/}")
			fi
		fi
		for candidate in "${candidates[@]}"
		do
			if [[ "${candidate}" = "${2}"* ]]
			then
				COMPREPLY+=("${candidate}")
			fi
		done
	}

	complete -F _ollama_completer_ ollama
fi
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	ollama "${@}"
fi
