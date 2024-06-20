# quicker cd to different drives on cygwin
if [ -d /cygdrive ]
then
	alias to=cd
	function to_() {
		readarray -t COMPREPLY < <(compgen -d "/cygdrive/${2}")
		COMPREPLY=("${COMPREPLY[@]/%//}")
	}
	complete -F to_ -o dirnames -o nospace to
fi

# if hit tab with empty cmd, don't search every dir in path
shopt -s no_empty_cmd_completion

# overwrite protection
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# reduce exit caused by C-d
export IGNOREEOF=100

# allow C-s commandline searching too
stty -ixon

# cd via number
# takes find arguments
# eg. -name 'a*' to give directories beginning with a
function lcd()
{
	local fnames
	local response
	defaults=('!' -name '.*')
	readarray -t fnames < <(find . -maxdepth 1 -mindepth 1 -type d -a "${@:-"${defaults[@]}"}" | sort)
	if [ "${#fnames[@]}" -gt 0 ]
	then
		paste -d: <(seq 0 $[${#fnames[@]} - 1]) <(printf '%s\n' "${fnames[@]##*/}") | column
		printf '\ncd to number: '
		read response
		if [[ "${response}" =~ ^[0-9]+$ ]] && [ "${response}" -ge 0 -a "${response}" -lt ${#fnames[@]} ]
		then
			cd "${fnames[response]}"
		fi
	else
		echo no dirs
	fi
}
