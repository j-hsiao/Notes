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

CHINFO_STRLEN_LUT=(
	# 126     1
	159     0   687     1   710     0   711     1
	727     0   733     1   879     0   1154    1   1161    0
	4347    1   4447    2   7467    1   7521    0   8369    1
	8426    0   9000    1   9002    2   11021   1   12350   2
	12351   1   12438   2   12442   0   19893   2   19967   1
	55203   2   63743   1   64106   2   65039   1   65059   0
	65131   2   65279   1   65376   2   65500   1   65510   2
	120831  1   262141  2   1114109 1
)

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
# after some testing, it seems like
# using a separate process might actually be faster
# even on cygwin
# since calculating the string length is still somewhat slow...
ci_charwidth() # <char> [out=RESULT]
{
	# Calculate the width of a character.
	# <char>: The character to convert.
	# [out]: The variable to store the result.
	local -n cicwidth__out="${2:-RESULT}"
	local codepoint
	printf -v codepoint '%d' "'${1}"

	# ascii is common case so search it first,
	# seems to approximately double strdisplaylen speed
	if ((codepoint <= 126))
	then
		cicwidth__out=$((codepoint != 0x0f && codepoint != 0x0e))
		return
	fi
	# Using the linear LUT table
	# local idx=0
	# while ((idx < ${#CHINFO_STRLEN_LUT[@]}))
	# do
	# 	if ((codepoint <= CHINFO_STRLEN_LUT[idx]))
	# 	then
	# 		cicwidth__out="${CHINFO_STRLEN_LUT[idx+1]}"
	# 		return
	# 	fi
	# 	((idx += 2))
	# done

	# using the binary tree, seems faster than the LUT
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

ci_codewidth() # <codepoint> [out=RESULT]
{
	# Calculate the width of a character corresponding to codepoint.
	# ci_charwidth would be equivalent to:
	# 	printf -v codepoint '%d' "'${1}"
	# 	ci_codewidth "${codepoint}"
	# <codepoint>: The character codepoint integer to convert.
	# [out]: The variable to store the result.
	local -n cicwidth__out="${2:-RESULT}"
	local codepoint="${1}"

	# ascii is common case so search it first,
	# seems to approximately double strdisplaylen speed
	if ((codepoint <= 126))
	then
		cicwidth__out=$((codepoint != 0x0f && codepoint != 0x0e))
		return
	fi
	# Using the linear LUT table
	# local idx=0
	# while ((idx < ${#CHINFO_STRLEN_LUT[@]}))
	# do
	# 	if ((codepoint <= CHINFO_STRLEN_LUT[idx]))
	# 	then
	# 		cicwidth__out="${CHINFO_STRLEN_LUT[idx+1]}"
	# 		return
	# 	fi
	# 	((idx += 2))
	# done

	# using the binary tree, seems faster than the LUT
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
	# NOTE: Tabs can be visually variable in length, but without position
	#       the actual length cannot be determined.  Avoid having tab
	#       characters in <word>.
	local idx=0 total=0 clen end=${#1}
	while ((idx < end))
	do
		ci_charwidth "${1:idx:1}" clen
		((total += clen))
		((++idx))
	done
	local -n cisdl__out="${2:-RESULT}"
	cisdl__out=${total}
}

CI_PYEXE=
for candidate in py python3 python
do
	if type "${candidate}" &>/dev/null
	then
		CI_PYEXE="${candidate}"
		break
	fi
done

if [[ -n "${CI_PYEXE}" ]]
then
	ci_strdisplaylens() # <out> <idx> <words...>
	{
		# Calculate ci_strdisplaylen for each word in <words>
		# and place into array <out> starting at index <idx>

		# ------------------------------
		# python implementation
		# ------------------------------
		readarray -O "${2}" -t "${1}" < <("${CI_PYEXE}" -c '
import sys

lut = (
    (126   , 1),
    (159   , 0),   (687   , 1),   (710    , 0),   (711  , 1),
    (727   , 0),   (733   , 1),   (879    , 0),   (1154 , 1),   (1161 , 0),
    (4347  , 1),   (4447  , 2),   (7467   , 1),   (7521 , 0),   (8369 , 1),
    (8426  , 0),   (9000  , 1),   (9002   , 2),   (11021, 1),   (12350, 2),
    (12351 , 1),   (12438 , 2),   (12442  , 0),   (19893, 2),   (19967, 1),
    (55203 , 2),   (63743 , 1),   (64106  , 2),   (65039, 1),   (65059, 0),
    (65131 , 2),   (65279 , 1),   (65376  , 2),   (65500, 1),   (65510, 2),
    (120831, 1),   (262141, 2),   (1114109, 1),
)


for item in sys.argv[1:]:
    total = 0
    for ch in item:
        num = ord(ch)
        if ch == 0x0f or ch == 0x0e:
            continue
        for (k, w) in lut:
            if num <= k:
                total += w
                break
    print(total)
    ' "${@:3}")
    return
	}
else
	ci_strdisplaylens() # <out> <idx> <words...>
	{
		# ------------------------------
		# using ci_strdisplaylen
		# ------------------------------
		local -n cisdls__out="${1}"
		local idx=${2}
		shift 2
		for x in "${@}"
		do
			ci_strdisplaylen "${x}" cisdls__out[idx]
			((++idx))
		done
	}
fi





if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo 'Testing chinfo.'
	for teststr in $'\e''[1,2':5 hello\ world:11 hello:5 world:5 eyy你好:7 $'has\ttab':7
	do
		ci_strdisplaylen "${teststr%:*}" out
		((out == ${teststr##*:})) && echo pass || printf 'failed "%s"\n\tgot : "%s"\n\twant: "%s"\n' "${teststr%:*}" "${out}" "${teststr##*:}"
	done
fi
