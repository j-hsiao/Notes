#!/bin/bash


if [[ "${BASH_SOURCE[0]}" != /* ]]
then
	. "${PWD}/${BASH_SOURCE[0]}"
else
	remind() {
		local script="${BASH_SOURCE[0]/remind.sh/../../python/tk/remind.py}"
		py "${script}" "${@}"
	}
fi
