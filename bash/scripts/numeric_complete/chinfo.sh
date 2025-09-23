#!/bin/bash

# Conversion between integers and characters.



chinfo_2char() # num [varname=RESULT]
{
	# Convert num into a character stored in varname.
	local -n chinfo__out="${2:-RESULT}"
	local num="${1}"
	if ((num <= 0xff))
	then
		local code=x length=2
	elif ((num <= 0xffff))
	then
		local code=u length=4
	elif ((num <= 0xffffffff))
	then
		local code=U length=8
	else
		chinfo__out=
		return 1
	fi
	# Is there a difference? portability?  It seems to have no
	# difference in performance.

	# printf -v num "\\\\%s%0${length}x" "${code}" "${num}"
	# chinfo__out="${num@E}"

	printf -v num "%0${length}x" "${num}"
	printf -v chinfo__out "\\${code}${num}"
}

chinfo_2num() # char [varname=RESULT]
{
	# Convert char into a number stored in varname.
	local -n chinfo__out="${2:-RESULT}"
	printf -v chinfo__out '%d' "'${1}"
}

# Calculate string widths, supporting unicode.
# https://stackoverflow.com/questions/36380867/how-to-get-the-number-of-columns-occupied-by-a-character-in-terminal
_CHINFO_STRLEN_LUT=(
	126     1   159     0   687     1   710     0   711     1
	727     0   733     1   879     0   1154    1   1161    0
	4347    1   4447    2   7467    1   7521    0   8369    1
	8426    0   9000    1   9002    2   11021   1   12350   2
	12351   1   12438   2   12442   0   19893   2   19967   1
	55203   2   63743   1   64106   2   65039   1   65059   0
	65131   2   65279   1   65376   2   65500   1   65510   2
	120831  1   262141  2   1114109 1
)

_CHINFO_STRLEN_TREE=(
                                                                                                   12442
                                                        8369                                                                            65131
                              879                                               11021                                 63743                                 65510
               710                          4447                        9000             12351              19967              65039              65376               262141
        159           727           1161            7521            8426    9002    12350     12438    19893     55203    64106     65059    65279     65500    120831      1114109
    126    687    711    733    1154    4347    7467     1         0    1  2    1  2     1   2     0  2     1   2     1  2     1   0     2  1     2   1     2  1      2    1        1
   1   0  1   0  1   0  1   0  1    0  1    2  1    0
)
chinfo_width() # char [RET]
{
	# Width of a character
	local -n chinfo__out="${2:-RET}"
	local codepoint
	printf -v codepoint '%d' "'${1}"

	if ((codepoint == 0x0f || codepoint == 0x0e))
	then
		chinfo__out=0
		return
	elif ((codepoint == 9))
	then
		# TODO what about tabs?
		# tabs kind of depend on where the character
		# starts... where the tabstop is... etc...
		chinfo__out="${_CHINFO_TABSTOP}"
	fi

	local idx=0
	while ((idx <= 37))
	do
		if ((codepoint <= _CHINFO_STRLEN_TREE[idx]))
		then
			((idx=idx*2 + 1))
		else
			((idx=idx*2 + 2))
		fi
		((++idx))
	done
	chinfo__out="${_CHINFO_STRLEN_TREE[idx]}"
}
