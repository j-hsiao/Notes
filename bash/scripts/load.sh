#!/bin/bash

case "${BASH_SOURCE[0]}" in
	*/*)
		dname="${BASH_SOURCE[0]%/*}"
		;;
	*)
		dname=.
		;;
esac
for f in "${dname}"/*
do
	if [[ "${f##*/}" != "${BASH_SOURCE[0]##*/}" ]]
	then
		. "${f}"
	fi
done
