#!/bin/bash


DEFAULTS=(-s 0 -n -t uint)
for x in blank-on-ac dpms-on-ac-off dpms-on-ac-sleep; do
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/"${x}" "${@:-"${DEFAULTS[@]}"}"
done
