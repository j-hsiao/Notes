#!/bin/bash

fds=32
declare -p fds

coproc fds { bash; }
# coproc will overwrite the variable name

echo "fds: ${fds[@]}"

printf 'trap %q EXIT\n' 'echo bash proc exited.' >&"${fds[1]}"
printf 'ls\n' >&"${fds[1]}"

while read -t 1 line
do
	echo ">>> ${line}"
done <&"${fds[0]}"

printf 'exit\n' >&"${fds[1]}"
echo "fds: ${fds[@]}"

while read -t 1 line
do
	echo "extra: ${line}"
done <&"${fds[0]}"

# variables are still available
echo "pid: ${fds_PID}"
echo "fds: ${fds[@]}"
declare -p fds

wait "${fds_PID}"
echo 'waited'

# variables are now unset after the coproc
# has exited and been waited on.
echo "pid: ${fds_PID}"
echo "fds: ${fds[@]}"
declare -p fds
