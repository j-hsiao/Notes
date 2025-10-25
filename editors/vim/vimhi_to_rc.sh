#!/bin/bash

# The format seems to be:
# (groupname) *xxx (settings | links to (groupname)

target=
while ((${#}))
do
	case "${1}" in
		-h|--help)
			printf 'usage: %s [-h] target

			[-h|--help]
			    Display this help message.
			target: The file to process
			    This file should be obtained from redirecting
			    the vim :hi command output to a file.
			    1. open vim
			    2. run commands:
			        :redir > destination
			        :hi
			        :redir END\n' "${BASH_SOURCE[0]}" | sed 's/^\t*//' >&2
			exit 1
			;;
		*)
			target="${1}"
			;;
	esac
	shift
done
if [[ -z "${target}" ]]
then
	echo "Need :hi file" >&2
	exit 1
fi

while read -a words
do
	if (("${#words[@]}"))
	then
		name="${words[0]}"
		echo "${words[@]}" >&2
		case "${words[2],,}" in
			links)
				echo :hi link "${name}" "${words[4]}"
				;;
			cleared)
				echo :hi "${name}" NONE
				;;
			*)
				echo :hi "${name}" "${words[@]:2}"
				;;
		esac
	fi
done < "${target}"
