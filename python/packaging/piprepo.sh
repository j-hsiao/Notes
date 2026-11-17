#!/bin/bash

# Generate a repo compatible with pip from wheels.

piprepo_index() { # dname [root]=
	# Create a simple html file to list each item.
	if ! shopt extglob &>/dev/null
	then
		trap 'trap - RETURN; shopt -u extglob' RETURN
		shopt -s extglob
	fi
	local dname="${1//+('/')/'/'}"
	local root="${2//+('/')/'/'}"
	if [[ "${dname}" != "${root}"* ]]
	then
		echo "root \"${root}\" does not prefix dir \"${dname}\"" >&2
		return 1
	fi
	if [[ ! -d "${dname}" ]]
	then
		echo "target \"${dname}\" is not a directory." >&2
		return 1
	fi

	local items=("${dname}"/*)
	items=("${items[@]##*/}")
	local rname="${dname#"${root}"}"
	[[ "${rname}" = /* ]] || rname="/${rname}"

	{
		echo '<!DOCTYPE html>'
		echo '<html lang="en">'
		echo '<head>'
		echo '<meta charset="utf-8">'
		echo "<title>Directory listing for ${rname}</title>"
		echo '</head>'
		echo '<body>'
		echo "<h1>Directory listing ${rname}</h1>"
		echo '<hr>'
		echo '<ul>'
		for item in "${items[@]}"
		do
			echo "<li><a href=\"${item}\">${item}</a></li>"
		done
		echo '</ul><hr></body></html>'
	} > "${dname}/index.html"
}

piprepo() { # reporoot wheels...
	# Create a repo containing specified wheels.
	local shopts=()
	local opt
	for opt in 'extglob' 'nullglob'; do
		shopt "${opt}" &>/dev/null || shopts+=("${opt}")
	done
	if ((${#shopts[@]}))
	then
		trap 'trap - RETURN; shopt -u "${shopts[@]}"' RETURN
		shopt -s "${shopts[@]}"
	fi
	local whls=() root=
	while (("${#}"))
	do
		case "${1}" in
			-h|--help)
				msg='piprepo <rootdir|wheelfile>...

				The last non-file item is taken as the root dir.
				rootdir: the directory to become the repo root.  Create
				  the directory if it does not exist.
				wheelfile: a wheel file.  It should be added to the repo.
				'
				echo "${msg//$'\t'}" >&2
				return
				;;
			*)
				if [[ -f "${1}" ]]
				then
					whls+=("${1}")
				else
					if [[ -n "${root}" ]]
					then
						echo "WARNING: multiple repos. Original: ${root}" >&2
					fi
					root="${1}"
				fi
				;;
		esac
		shift
	done

	for whl in "${whls[@]}"
	do
		local name="${whl##*/}"
		name="${name%%-*}"
		name="${name//+([-_.])/-}"
		[[ -d "${root}/${name}" ]] || mkdir -p "${root}/${name}"
		ln -s "${whl}" "${root}/${name}"
	done
	piprepo_index "${root}" "${root}"
	for whl in "${root}"/*/
	do
		piprepo_index "${whl}" "${root}"
	done
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]
then
	piprepo "${@}"
else
	piprepo() { bash "${BASH_SOURCE[0]}" "${@}"; }
fi
