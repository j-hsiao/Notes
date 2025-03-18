#!/bin/bash
# Mount windows drives, usually network drive from `net use X: \\some\server\whatever`
#
# usage: winmount a b c...
# where a, b, c, are network drives to mount.
# ex.
# 	in windows:
# 	net use X: \\my.server\something
#
# 	in wsl:
# 	winmount x
#
# 	/mnt/x should refer to \\my.server\something now.
winmount()
{
	for arg in "${@}"
	do
		case "${arg}" in
			-h|--help)
				echo 'usage: winmount [disk letter]'
				echo 'example: winmount z'
				echo 'Makes directory /mnt/z and mounts windows Z: to /mnt/z'
				return
				;;
			*)
				if [[ "${#arg}" -eq 1 ]]
				then
					if [ ! -d /mnt/${arg,,} ]
					then
						sudo mkdir "/mnt/${arg,,}"
					fi
					sudo mount -t drvfs "${arg^^}:" "/mnt/${arg,,}"
				else
					echo "unknown arg \"${arg}\""
					return 1
				fi
		esac
	done
}
