#!/bin/bash

pyenvinit() {
	# https://github.com/pyenv/pyenv
	# https://github.com/pyenv/pyenv#d-install-python-build-dependencies
	local installdeps
	local dryrun=
	local distro=
	while (("${#}"))
	do
		case "${1,,}" in
			-d|--dryrun)
				dryrun=echo
				;;
			-h|--help)
				local msg='usage: pyenvinit [-h] [-d] [architecture]
				-h|--help: print this help message
				-d|--dryrun: print install commands instead of doing it.
				architecture: the architecture.
				    recogized: arch|ubuntu|debian
				    anything else: try to detect.'
				echo "${msg//$'\t'}"
				return
				;;
			ubuntu|arch|debian)
				distro="${1,,}"
				;;
			*)
				distro=' '
				;;
		esac
		shift
	done

	if declare -f pyenv &>/dev/null
	then
		echo 'pyenv already initted'
	else
		if [[ -z "${PYENV_ROOT}" ]]
		then
			if [[ -d ~/.pyenv/bin ]]
			then
				export PYENV_ROOT="${HOME}/.pyenv"
			else
				if [[ -n "${dryrun}" ]]
				then
					echo 'pyenv bin dir not found.'
					echo 'run: git clone https://github.com/pyenv/pyenv.git ~/.pyenv'
					echo 'Or set PYENV_ROOT env var.'
					return
				else
					git clone https://github.com/pyenv/pyenv.git ~/.pyenv
					pyenvinit ${distro}
					return
				fi
			fi
		fi
		if [[ ":${PATH}:" != ":${PYENV_ROOT}/bin:" ]]
		then
			export PATH="${PYENV_ROOT}/bin${PATH:+:${PATH}}"
		fi
		. <(pyenv init -)
	fi
	if [[ -n "${distro}" ]]
	then
		if [[ -z "${distro//[[:blank:]]}" ]]
		then
			if hash lsb_release &>/dev/null
			then
				distro="$(lsb_release -i)"
				distro="${distro#*: }"
			elif hash pacman &>/dev/null
			then
				distro=arch
			elif hash apt &>/dev/null
			then
				distro=ubuntu
			fi
		fi
		distro="${distro//[[:blank:]]}"
		case "${distro,,}" in
			arch)
				${dryrun} sudo pacman -S --needed base-devel openssl zlib xz tk zstd
				;;
			ubuntu|debian)
				${dryrun} sudo apt update
				${dryrun} sudo apt install make build-essential libssl-dev zlib1g-dev \
					libbz2-dev libreadline-dev libsqlite3-dev curl git \
					libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libzstd-dev
				;;
			'')
				echo "Failed to detect distro."
				;;
			*)
				echo "Distro ${distro} python build deps unimplemented."
				echo 'check https://github.com/pyenv/pyenv#d-install-python-build-dependencies'
				;;
		esac
	fi
}
