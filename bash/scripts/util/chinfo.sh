#!/bin/bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && declare -Fp ci_2char &>/dev/null && (($# == 0)) && return

# Conversion between integers and characters.
ci_2char() # <num> [outname=RESULT]
{
	# Convert num into a character
	# <num>: the number to convert
	# [outname]: the variable to store the result.
	local -n ci2c__out="${2:-RESULT}"
	local ci2c__num="${1}"
	if ((ci2c__num <= 0xff))
	then
		local ci2c__code=x ci2c__length=2
	elif ((ci2c__num <= 0xffff))
	then
		local ci2c__code=u ci2c__length=4
	elif ((ci2c__num <= 0xffffffff))
	then
		local ci2c__code=U ci2c__length=8
	else
		ci2c__out=
		return 1
	fi
	printf -v ci2c__num "%0${ci2c__length}x" "${ci2c__num}"
	printf -v ci2c__out "\\${ci2c__code}${ci2c__num}"
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
CHINFO_STRLEN_TREE=(
	12442 # 0
	8369 65131 # 1-2
	879 11021 63743 65510 # 3-6
	710 4447 9000 12351 19967 65039 65376 262141 # 7-14
	159 727 1161 7521 8426 9002 12350 12438 19893 55203 64106 65059 65279 65500 120831 1114109 # 15-30
	126 687 711 733 1154 4347 7467 1 0 1 2 1 2 1 2 0 2 1 2 1 2 1 0 2 1 2 1 2 1 2 1 1 # 31-62
	1 0 1 0 1 0 1 0 1 0 1 2 1 0 # 63-76
)

ci_codewidth() # <codepoint> [out=RESULT]
{
	# Calculate the width of a character corresponding to codepoint.
	# ci_charwidth would be equivalent to:
	# 	printf -v codepoint '%d' "'${1}"
	# 	ci_codewidth "${codepoint}"
	# <codepoint>: The character cw__codepoint integer to convert.
	# [out]: The variable to store the result.
	local -n cicw__out="${2:-RESULT}"
	local cicw__codepoint="${1}"

	# ascii is common case so search it first,
	# seems to approximately double strdisplaylen speed
	if ((cicw__codepoint <= 126))
	then
		cicw__out=$((cicw__codepoint != 0x0f && cicw__codepoint != 0x0e))
		return
	fi
	local cicw__idx=0

	# Using the linear LUT table
	# while ((cicw__idx < ${#CHINFO_STRLEN_LUT[@]}))
	# do
	# 	if ((cicw__codepoint <= CHINFO_STRLEN_LUT[cicw__idx]))
	# 	then
	# 		cicw__out="${CHINFO_STRLEN_LUT[cicw__idx+1]}"
	# 		return
	# 	fi
	# 	((cicw__idx += 2))
	# done

	# using the binary tree, seems faster than the LUT
	while ((cicw__idx <= 37))
	do
		if ((cicw__codepoint <= CHINFO_STRLEN_TREE[cicw__idx]))
		then
			((cicw__idx=cicw__idx*2 + 1))
		else
			((cicw__idx=cicw__idx*2 + 2))
		fi
	done
	cicw__out="${CHINFO_STRLEN_TREE[cicw__idx]}"
}
ci_charwidth() # <char> [out=RESULT]
{
	local cicw__codepoint
	printf -v cicw__codepoint '%d' "'${1}"
	ci_codewidth "${cicw__codepoint}" "${2}"
}


ci_strdisplaylen() # <word> [out=RESULT]
{
	# Calculate the displayed length of a word.
	# <word>: The word to process.
	# [out]: The variable to store the result.
	# NOTE: Tabs can be visually variable in length, but without position
	#       the actual length cannot be determined.  Avoid having tab
	#       characters in <word>.
	local cisdl__idx=-1 cisdl__total=0 cisdl__clen cisdl__end=${#1}
	while ((++cisdl__idx < cisdl__end))
	do
		ci_charwidth "${1:cisdl__idx:1}" cisdl__clen
		((cisdl__total += cisdl__clen))
	done
	local -n cisdl__out="${2:-RESULT}"
	cisdl__out=${cisdl__total}
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

		# python subprocess overhead is higher, especially on cygwin.
		# If only a few items, then use bash instead.
		if ((${#} < 1000))
		then
			local -n cisdls__out="${1}"
			local cisdls__offset="${2:-0}"
			shift 2
			local cisdls__idx cisdls__stop="${#}"
			for ((cisdls__idx=0; cisdls__idx<cisdls__stop; ++cisdls__idx))
			do
				ci_strdisplaylen "${1}" "cisdls__out[cisdls__idx + cisdls__offset]"
				shift
			done
			return
		fi

		# ------------------------------
		# python implementation
		# ------------------------------
		if ((0))
		then
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
		else
			readarray -O "${2}" -t "${1}" < <("${CI_PYEXE}" -c '
import sys
tree=(
    12442,
    8369, 65131,
    879, 11021, 63743, 65510,
    710, 4447, 9000, 12351, 19967, 65039, 65376, 262141,
    159, 727, 1161, 7521, 8426, 9002, 12350, 12438, 19893, 55203, 64106, 65059, 65279, 65500, 120831, 1114109,
    126, 687, 711, 733, 1154, 4347, 7467, 1, 0, 1, 2, 1, 2, 1, 2, 0, 2, 1, 2, 1, 2, 1, 0, 2, 1, 2, 1, 2, 1, 2, 1, 1,
    1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 1, 0,
)
for item in sys.argv[1:]:
    total = 0
    for ch in item:
        num = ord(ch)
        if num <= 126:
            total += num != 0x0f and num != 0x0e
            continue
        i=0
        while i <= 37:
            if num <= tree[i]:
                i = i*2 + 1
            else:
                i = i*2 + 2
        total += tree[i]
    print(total)
			' "${@:3}")
		fi
	}
else
	ci_strdisplaylens() # <out> <idx> <words...>
	{
		# ------------------------------
		# using ci_strdisplaylen
		# ------------------------------
		local -n cisdls__out="${1}"
		local cisdls__offset="${2:-0}"
		shift 2
		local cisdls__idx cisdls__stop="${#}"
		for ((cisdls__idx=0; cisdls__idx<cisdls__stop; ++cisdls__idx))
		do
			ci_strdisplaylen "${1}" "cisdls__out[cisdls__idx + cisdls__offset]"
			shift
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
