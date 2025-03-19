#!bin/bash

# Observations:
# WSL seems to open an extra bash session that also sources .bashrc
# As a result, opening a single WSL terminal results in a sync count of 2...
# "${-}" are identical among all the started bash sessions (himBH).
# flag s is also added after initial startup.
# Generally, it seems like the only way to distinguish is to see what
# PPID is and check the command.  Actual wt terminal bash sessions
# seem to be child of a /init process, whereas the extra seems to be
# a child of a /bin/login process with egroup != root.
# From the actual process itself, can't find a differentiating property
# to use, so must check ppid info maybe...


synclog()
{
	flock /dev/shm/.log_sync_exit bash -c '
		printf "%s %d: flags(%s)\\nparent id: %d\\n" "${0}" "${1}" "${2}" "${3}" >> /dev/shm/.log_sync_exit
		ps -o euser,egroup,f,ppid,comm,args -p "${1},${3}" >> /dev/shm/.log_sync_exit
	' "${1}" "$$" "${-}" "${PPID}"
}

synclog sourced_sync_exit


if [[ "$(ps -o args -p ${PPID} --no-header)" == '/init' ]]
then
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
				echo 1 > /dev/shm/.sync_exit
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
fi
