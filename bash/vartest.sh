#!/bin/bash

# 3 types of variables:
# local: local to current scope, visible in lower scopes (function calls)
# raw  : no local or global specifier
# global: explicitly global variable
# need 3 scopes, declare all 3 types and modify previous ones etc...
#
# variable names: [goi][glr]
# global/outer/inner:   variable declaration location.
# global/local/raw:     variable type.
#
# gl not allowed, local must be in function scope
#
#
# conclusions:
# raw variables are global variables.
# setting variables raw keeps its local/globalness
# (local outer was changed in inner and outer saw the change, but global did not see the local outer var)
#
#


declare -g gg=g
gr=g


inner()
{
	declare -g ig=i
	local il=i
	ir=i
	cat << EOF
-------------
inner scope

gg=${gg}
gr=${gr}

og=${og}
ol=${ol}
or=${or}

ig=${ig}
il=${il}
ir=${ir}
EOF
	gg+=i
	gr+=i
	og+=i
	ol+=i
	or+=i
}

outer()
{
	declare -g og=o
	local ol=o
	or=o
	cat << EOF
-------------
outer before

gg=${gg}
gr=${gr}

og=${og}
ol=${ol}
or=${or}

ig=${ig}
il=${il}
ir=${ir}
EOF

	gg+=o
	gr+=o

	inner

	cat << EOF
-------------
outer after

gg=${gg}
gr=${gr}

og=${og}
ol=${ol}
or=${or}

ig=${ig}
il=${il}
ir=${ir}
EOF
}


cat << EOF
-------------
global before

gg=${gg}
gr=${gr}

og=${og}
ol=${ol}
or=${or}

ig=${ig}
il=${il}
ir=${ir}
EOF
outer

cat << EOF
-------------
global after

gg=${gg}
gr=${gr}

og=${og}
ol=${ol}
or=${or}

ig=${ig}
il=${il}
ir=${ir}
EOF


# output variable:
# https://stackoverflow.com/a/55331060

use_echo()
{
	echo "${1} is a ${2}"
}

use_print()
{
	printf -v "${3}" '%s' "${1} is a ${2}"
}

use_declare()
{
	declare -n use_declare_localv="${1}"
	use_declare_localv="${1} is a ${2}"
}
use_fixed()
{
	RESPONSE="${1} is a ${2}"
}

use_read()
{
	IFS=$'\n' read "${3}" <<<"${1} is a ${2}"
}

declare -A OUTPUTS_ARRAY
use_array()
{
	OUTPUTS_ARRAY["${3}"]="${1} is a ${2}"
}

timeitecho()
{
	local method="use_echo" i=0 c
	while [[ "${i}" -lt "${reps}" ]]
	do
		c=$(use_echo a b)
		i=$((i+1))
	done
}

timeitfixed()
{
	local method="use_echo" i=0 c RESPONSE
	while [[ "${i}" -lt "${reps}" ]]
	do
		use_fixed a b
		c="${RESPONSE}"
		i=$((i+1))
	done
}

timeitvar()
{
	local method="use_${1}" i=0 c
	while [[ "${i}" -lt "${reps}" ]]
	do
		"${method}" a b c
		i=$((i+1))
	done
}



reps=1000
echo "using echo"
time timeitecho
echo "using print"
time timeitvar print
echo "using read"
time timeitvar read
echo "using declare"
time timeitvar declare
echo "using array"
time timeitvar array
echo "using fixed"
time timeitfixed
