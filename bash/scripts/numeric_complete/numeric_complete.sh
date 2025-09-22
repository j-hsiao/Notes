#!/bin/bash

# Numeric tab completion.
# Internal state is stored in the _NC_STATE associative array environment variable.
# This allows state to be saved between function calls (For example, caching the
# result of listing a directory).

declare -A _NC_STATE

# The readline completion-ignore-case and show-mode-in-prompt
# settings are needed to determine numeric completion behavior.
# However, on Cygwin, bind is noticeably very slow.  A solution
# would be to cache the value of the settings into variables.

_NC_STATE['completion_ignore_case']=
_NC_STATE['show_mode_in_prompt']=
if ! declare -f _NC_orig_bind &>/dev/null
then
	case "$(type -t bind)" in 
		file|builtin)
			_NC_orig_bind() { command bind "${@}"; }
			;;
		function)
			if [[ ! "$(declare -f bind)" =~ .*'_NC_orig_bind ' ]]
			then
				printf 'Warning, experimental overriding function bind.\n'
				eval _NC_orig_"$(declare -f bind)"
			else
				printf 'bind is a function that already references _NC_orig_bind\n'
			fi
			;;
		alias)
			printf 'Warning, experimental overriding alias bind.\n'
			_NC_STATE['bind_alias']=$(alias bind)
			_NC_orig_bind() {
				alias bind="${_NC_STATE['bind_alias']}"
				bind
				unalias bind
			}
			unalias bind
			;;
		*)
			printf 'Warning, overriding unknown bind implementation.'
			_NC_orig_bind() { command bind "${@}"; }
			;;
	esac
	bind() {
		_NC_orig_bind "${@}"
		local ret=$?
		local data="$(_NC_orig_bind -v)"
		local tmp="${data#*completion-ignore-case }"
		_NC_STATE['completion_ignore_case']="${tmp:0:2}"
		tmp="${data#*show-mode-in-prompt }"
		_NC_STATE['show_mode_in_prompt']="${tmp:0:2}"
		return "${ret}"
	}
	bind
fi

NUMERIC_COMPLETE_set_pager()
{
	# Set NUMERIC_COMPLETE_pager variable to use less if available.
	NUMERIC_COMPLETE_pager=()
	local lessname lessver lessother
	if read lessname lessver lessother < <(less --version 2>&1)
	then
		if [[ "${lessver}" =~ ^[0-9]+$ ]]
		then
			if [[ "${lessver}" -ge 600 ]]
			then
				NUMERIC_COMPLETE_pager=(less -R -~ --header 2)
			else
				NUMERIC_COMPLETE_pager=(less -R -~ +1)
			fi
			return
		fi
	fi
	if (("${#}"))
	then
		NUMERIC_COMPLETE_pager=("${@}")
	fi
}
