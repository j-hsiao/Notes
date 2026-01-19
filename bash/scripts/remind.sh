#!/bin/bash
# Run the remind.py script.

if [[ "${BASH_SOURCE[0]}" != /* ]]
then
	# It seems that the path at sourcing time is used verbatim.
	# As a result, if you do . ./fname, it will see BASH_SOURCE as ./fname
	# forever, even if you cd away.  As a result, sourcing should
	# probably always use absolute path if BASH_SOURCE will be used.
	. "${PWD}/${BASH_SOURCE[0]}"
else
	remind() {
		local script="${BASH_SOURCE[0]/remind.sh/../../python/tk/remind.py}"
		# require the py func to call the right python or clear TZ if cygwin.
		if ! declare -f py &>/dev/null
		then
			. "${BASH_SOURCE[0]/remind.sh/py.sh}"
		fi
		py "${script}" "${@}"
	}
fi
