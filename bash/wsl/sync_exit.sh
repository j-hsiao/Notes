#!bin/bash


flocksync_incr_count()
{
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
