#!/bin/bash

# Conversion between integers and characters.

ci_2char() # <num> [outname=RESULT]
{
	# Convert num into a character
	# <num>: the number to convert
	# [outname]: the variable to store the result.
	local -n ci2c__out="${2:-RESULT}"
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
		ci2c__out=
		return 1
	fi
	# Is there a difference? portability?  It seems to have no
	# difference in performance.

	# printf -v num "\\\\%s%0${length}x" "${code}" "${num}"
	# ci2c__out="${num@E}"

	printf -v num "%0${length}x" "${num}"
	printf -v ci2c__out "\\${code}${num}"
}

ci_2num() # <char> [outname=RESULT]
{
	# Convert char into a number stored in outname.
	# <char>: the character to convert.
	# [outname]: the variable to store the result.
	local -n ci2n__out="${2:-RESULT}"
	printf -v ci2n__out '%d' "'${1}"
}

# Calculate string widths, supporting unicode.
# https://stackoverflow.com/questions/36380867/how-to-get-the-number-of-columns-occupied-by-a-character-in-terminal

# Reorganized the table into a binary tree, 38 pivot points, rest are leaf nodes
CHINFO_STRLEN_TREE=( \
	12442 \
	8369 65131 \
	879 11021 63743 65510 \
	710 4447 9000 12351 19967 65039 65376 262141 \
	159 727 1161 7521 8426 9002 12350 12438 19893 55203 64106 65059 65279 65500 120831 1114109 \
	126 687 711 733 1154 4347 7467 1 0 1 2 1 2 1 2 0 2 1 2 1 2 1 0 2 1 2 1 2 1 2 1 1 \
	1 0 1 0 1 0 1 0 1 0 1 2 1 0 \
)
ci_charwidth() # <char> [out=RESULT]
{
	# Calculate the width of a character.
	# <char>: The character to convert.
	# [out]: The variable to store the result.
	local -n cicwidth__out="${2:-RESULT}"
	local codepoint
	printf -v codepoint '%d' "'${1}"

	if ((codepoint == 0x0f || codepoint == 0x0e))
	then
		cicwidth__out=0
		return
	fi

	local idx=0
	while ((idx <= 37))
	do
		if ((codepoint <= CHINFO_STRLEN_TREE[idx]))
		then
			((idx=idx*2 + 1))
		else
			((idx=idx*2 + 2))
		fi
		((++idx))
	done
	cicwidth__out="${CHINFO_STRLEN_TREE[idx]}"
}

ci_strdisplaylen() # <word> [out=RESULT]
{
	# Calculate the displayed length of a word.
	# <word>: The word to process.
	# [out]: The variable to store the result.
	# NOTE: Tab will count as 1 character even if it might be displayed
	#       as multiple characters.  This is because tabs can be a different
	#       width depending on the environment as well as the position where
	#       it is placed.  Since the length is not fixed, just count it as 1.
	local idx=1 total=0 clen
	[[ "${1}" =~ ${1//?/(.)} ]] # load single characters into BASH_REMATCH
	while ((idx < ${#BASH_REMATCH[@]}))
	do
		ci_charwidth "${BASH_REMATCH[idx]}" clen
		((total += clen))
		((++idx))
	done
	local -n cisdl__out="${2:-RESULT}"
	cisdl__out=${total}
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo 'Testing chinfo.'
	for teststr in $'\e''[1,2':5 hello\ world:11 hello:5 world:5 eyy你好:7 $'has\ttab':7
	do
		ci_strdisplaylen "${teststr%:*}" out
		((out == ${teststr##*:})) && echo pass || printf 'failed "%s"\n\tgot : "%s"\n\twant: "%s"\n' "${teststr%:*}" "${out}" "${teststr##*:}"
	done
fi
