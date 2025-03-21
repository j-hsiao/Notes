#!bin/bash

# Goal:
# 	Call then sync command on exit whenever the last wsl bash session is closed.
# Problems:
# 	From observation, WSL seems to open one extra bash process.  It appears
# 	to be identical to other bash processes that are connected to terminal.
# 	(checked ${-}).  Furthermore, it seems like .bash_profile is always
# 	sourced if it exists in wsl so it can't be used to distinguish.
# 	Also, the bash processes never seem to have the l flag for login shell.
#
# 	The only way to distinguish it from processes connected to terminals is
# 	to look at the parent process.
# 	Run the command: ps --no-header -o euser,egroup,comm,args -p $PPID
# 	Bash processes connected to a terminal:
# 		root     root     Relay(403)      /init
# 	where the 403 seems to correspond to "${$}"
# 	The extra bash process:
# 		root     jason    login           /bin/login -f
#
# 	One solution is to check the parent process info and see if it is
# 	the expected value for terminal-connected bash session. 
# 	The other solution is to just not increment if the count file does
# 	not exist.  This means that one of the bash sessions will not be
# 	counted.  Note that the extra session seems to be created AFTER the
# 	first terminal bash session which means that the functions should
# 	all be defined always in this case.
#
synclog()
{
	flock /dev/shm/.log_sync_exit bash -c '
		printf "%s %d\\n" "${0}" "${1}" >> /dev/shm/.log_sync_exit
	' "${1}" "$$"
}

synclog sourced_sync_exit
flocksync_incr_count()
{
	synclog flock_incr
	flock /dev/shm/.sync_exit bash -c '
		number=$(cat /dev/shm/.sync_exit)
		if [[ "${number}" =~ ^[0-9]+$ ]]
		then
			((++number))
			echo "${number}" > /dev/shm/.sync_exit
		else
			echo "Initialize .sync_exit file."
			echo 0 > /dev/shm/.sync_exit
		fi
		'
}

flocksync_decr_count()
{
	synclog flock_decr
	flock /dev/shm/.sync_exit bash -c '
		number=$(cat /dev/shm/.sync_exit)
		if [[ "${number}" =~ ^[0-9]+$ ]]
		then
			((--number))
			echo "${number}" > /dev/shm/.sync_exit
			if [[ "${number}" -eq 0 ]]
			then
				sync
			fi
		else
			printf "WARNING! sync number is not numeric (${number})\\npress return to continue..."
			read
		fi
		'
}

flocksync_incr_count

exit()
{
	flocksync_decr_count
	command exit
}
