# quicker cd to different drives on cygwin
if [ -d /cygdrive ]
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
