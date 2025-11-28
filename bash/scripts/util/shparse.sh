#!/bin/bash

# Parse a string as it would be parsed by bash.
# The string might be incomplete, using eval would result in an error.
#
# Useful information would be:
# 	innermost incomplete expression to run completion on.
# 	end of an subexpression
# 	The bash-interpreted value
#
# With these considerations, all shparse_parse_* functions have signature:
# name <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
#
# <text>: the text to parse.
# [out]: The name of the output variable.  The evaluated text (parameters
#        expanded, command substitution, etc) will be stored into this
#        variable.  Use an invalid variable name to prevent this evaluation
#        if you only want the start/count values.  If empty, it will default
#        to RESULT.  If the expression is incomplete, then nothing will be done.
# [begin]: The name of the variable to store the start of the parsed
#          expression.  This might or might not match the given start
#          value eg. if there is an incomplete subexpression.  In that case,
#          start will point to its starting position.
# [end]: The variable name to store the ending position (exclusive) position.
#        That is to say, ${text:begin:end-begin} will be the parsed expression.
#        if end exists, then it is the first character NOT in the parsed expression.
#        If the expression is incomplete, this will be -1.
# [initial]: The initial beginning position
#
# To avoid redundant checks, parsing functions assume that <text>
# starts with the corresponding characters for the target expression type.
# Otherwise, behavior is undefined.
#
# Example:
# 	${myvar:-${HO<Tab>}}
#
# 	This is incomplete so out will be empty if it was given.
# 	start will be 9 (at the beginning of the ${HO} expr
# 	count will be -1 (it was incomplete)
#
#
# handled expressions:
# $'...'
# '...'
# "..."
# ${...}
# $(...)
# $((...))
# `...`

. "${BASH_SOURCE[0]%shparse.sh}restore_rematch.sh"

# vim brace/paren matching gets messed up
# when there are many strings/escapes of (){}
OPENBRACE='{'
CLOSEBRACE='}'
OPENPAREN='('
CLOSEPAREN=')'

is_variable() # <varname>
{
	# Success if is variable name, else error.
	local orig=("${BASH_REMATCH[@]}")
	[[ "${1}" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]]
	local ret=$?
	restore_BASH_REMATCH orig
	return "${ret}"
}

shparse_parse_ansi_c() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as ansi-c quote from assumed $' until an ending '.
	eval "${3:-BEG}"='"${5:-0}"'
	local orig_rematch=("${BASH_REMATCH[@]}")
	[[ "${1:2 + ${5:-0}}" =~ ^(\\.|[^\\\'])*\' ]]
	if [[ -n "${BASH_REMATCH[0]}" ]]
	then
		eval "${4:-END}="'"$((${5:-0} + 2 + "${#BASH_REMATCH[0]}"))"'
		if is_variable "${2:-RESULT}"
		then
			eval "${2:-RESULT}=\$'${BASH_REMATCH[0]}"
		fi
	else
		eval "${4:-END}=-1"
	fi
	restore_BASH_REMATCH orig_rematch
}

shparse_parse_single_quote() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a single-quote string from assumed ' to ending '.

	# From man bash:
	# Enclosing characters in single quotes preserves the literal value
	# of each character within the quotes.  A single quote may not occur
	# between single quotes, even when preceded by a backslash.
	# simple, just find the next single quote
	eval "${3:-BEG}="'"${5:-0}"'

	local orig_rematch=("${BASH_REMATCH[@]}")
	[[ "${1:${5:-0}+1}" =~ ^[^\']*\' ]]
	if [[ -n "${BASH_REMATCH[0]}" ]]
	then
		eval "${4:-END}="'"$((${#BASH_REMATCH[0]}+1+${5:-0}))"'
		if is_variable "${2:-RESULT}"
		then
			eval "${2:-RESULT}='${BASH_REMATCH[0]}"
		fi
	else
		eval "${4:-END}=-1"
	fi
	restore_BASH_REMATCH orig_rematch
}

shparse_parse_double_quote() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a double-quote string from assumed " to ending ".

	# From man bash:
	# Enclosing characters in double quotes preserves the literal value
	# of all characters within the quotes, with the exception of $, `,
	# \, and, when history expansion is enabled, !.  When the shell  is
	# in  posix mode, the ! has no special meaning within double
	# quotes, even when history expansion is enabled.  The characters $
	# and ` retain their special meaning within double quotes.  The
	# backslash retains its special meaning only when followed by one
	# of the following characters: $, `, ", \, or <newline>.  A double
	# quote may be quoted within double quotes by preceding it  with  a
	# backslash.  If enabled, history expansion will be performed
	# unless an !  appearing in double quotes is escaped using a
	# backslash.  The backslash preceding the !  is not removed.
	#
	# for now, don't support history... in completions.

	local orig_rematch=("${BASH_REMATCH[@]}")
	local -n shppdq__end="${4:-END}"
	((shppdq__end = "${5:-0}" + 1))

	while true
	do
		[[ "${1:shppdq__end}" =~ (\\.|[^'"$`']|\$\')*(\"|\$.|\`) ]]

		if [[ -z "${BASH_REMATCH[0]}" ]]
		then
			shppdq__end=-1
			eval "${3:-BEG}="'"${5:-0}"'
			restore_BASH_REMATCH orig_rematch
			return
		fi
		case "${BASH_REMATCH[2]}" in
			\"|\$\")
				# end of string
				eval "${3:-BEG}="'"${5:-0}"'
				((shppdq__end+=${#BASH_REMATCH[0]}))
				if is_variable "${2:-RESULT}"
				then
					eval "${2:-RESULT}=${1: ${5:-0} : shppdq__end - ${5:-0}}"
				fi
				restore_BASH_REMATCH orig_rematch
				return
				;;
			\$*)
				local subparse=shparse_parse_dollar
				;;
			\`)
				local subparse=shparse_parse_backtick
				;;
		esac
		"${subparse}" "${1}" 0 "${3}" "${4}" \
			$((shppdq__end + ${#BASH_REMATCH[0]} - ${#BASH_REMATCH[2]}))
		if ((shppdq__end < 0))
		then
			restore_BASH_REMATCH orig_rematch
			return
		fi
	done
}

shparse_parse_backtick() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a backtick command substitution
	# from assumed backtick to ending backtick.

	# From man bash:
	# When the old-style backquote form of substitution is used,
	# backslash retains its literal meaning except when followed by $,
	# `, or \.  The first backquote not preceded by a backslash
	# terminates the command substitution.
	#
	# This means even though backtick might appear in a subexpression
	# (string, parameter sub, etc...) they MUST be escaped or it
	# will end the command substitution expression right there.
	# As a result, the backtick region must be found first
	# before subexpressions are parsed or the ending backtick
	# might be interpreted as part of a subexpression instead.

	local orig_rematch=("${BASH_REMATCH[@]}")
	local -n shppbt__end="${4:-END}"

	[[ "${1: ${5:-0}}" =~ \`(\\.|[^\`])*\` ]]
	if [[ -z "${BASH_REMATCH[0]}" ]]
	then
		local region="${1}"
		local tickfix=0
	else
		local region="${1:0:${5:-0} + ${#BASH_REMATCH[0]} - 1}"
		local tickfix=1
	fi
	shppbt__end=$((${5:-0} + 1))
	local ending="${#region}"

	while ((shppbt__end < ending))
	do
		[[ "${region: shppbt__end}" =~ (\\.|[^'$"'\'])* ]]
		if ((shppbt__end + ${#BASH_REMATCH[0]} == ending))
		then
			break
		fi
		case "${region: shppbt__end+${#BASH_REMATCH[0]}:1}" in
			\$)
				local subparse=shparse_parse_dollar
				;;
			\')
				local subparse=shparse_parse_single_quote
				;;
			\")
				local subparse=shparse_parse_double_quote
				;;
		esac
		${subparse} "${region}" 0 "${3}" "${4}" $((shppbt__end + ${#BASH_REMATCH[0]}))
		if ((shppbt__end < 0))
		then
			restore_BASH_REMATCH orig_rematch
			return
		fi
	done
	eval "${3:-BEG}"='"${5:-0}"'
	if ((tickfix))
	then
		eval "${4:-END}=$((ending+1))"
		if is_variable "${2:-RESULT}"
		then
			eval "${2:-RESULT}"="${1: ${5:-0} : ending + 1 - ${5:-0}}"
		fi
	else
		eval "${4:-END}=-1"
	fi
	restore_BASH_REMATCH orig_rematch
	return
}

shparse_parse_parameter_expansion() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a parameter expansion from assumed ${ to ending }.
	local orig_rematch=("${BASH_REMATCH[@]}")
	local -n shpppe__end="${4:-END}"
	shpppe__end=$((${5:-0} + 2))

	local interrupt='$"`'\}\'
	while true
	do
		[[ "${1: shpppe__end}" =~ (\\.|[^"${interrupt}"])*(["${interrupt}"]) ]]
		case "${BASH_REMATCH[2]}" in
			\})
				eval "${3:-BEG}="'"${5:-0}"'
				((shpppe__end += "${#BASH_REMATCH[0]}"))
				if is_variable "${2:-RESULT}"
				then
					eval "${2:-RESULT}=${1: ${5:-0} : shpppe__end}"
				fi
				restore_BASH_REMATCH orig_rematch
				return
				# proper end the parameter expansion
				;;
			\$)
				local subparse=shparse_parse_dollar
				;;
			\`)
				local subparse=shparse_parse_backtick
				;;
			\")
				local subparse=shparse_parse_double_quote
				;;
			\')
				local subparse=shparse_parse_single_quote
				;;
			'')
				# no match, incomplete, up to remainder
				shpppe__end=-1
				eval "${3:-BEG}="'"${5:-0}"'
				return
				;;
		esac
		${subparse} "${1}" 0 "${3}" "${4}" \
			$(("${shpppe__end}" + "${#BASH_REMATCH[0]}" - ${#BASH_REMATCH[2]}))
		if ((shpppe__end < 0))
		then
			restore_BASH_REMATCH orig_rematch
			return;
		fi
	done
}

shparse_parse_math() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as math expr from assumed $(( to ending ))
	# NOTE, in the bash manual, $[...] is deprecated and will be removed in
	# upcoming versions of bash, so for now, not going to bother implementing that.

	# The expression is treated as if it were within double quotes, but
	# a double quote inside the parentheses is not treated specially.
	# All tokens in the expression undergo parameter and  variable  ex‐
	# pansion, command substitution, and quote removal.  The result is
	# treated as the arithmetic expression to be evaluated.  Arithmetic
	# expansions may be nested.
	local depth=0
	local orig_rematch=("${BASH_REMATCH[@]}")

	local -n shppm__end="${4:-END}"
	shppm__end=$((${5:-0} + 3))
	eval "${3:-BEG}=${5:-0}"

	while true
	do
		[[ "${1:shppm__end}" =~ [^()]*([()$\'\"\`]) ]]
		case "${BASH_REMATCH[1]}" in
			\$)
				local subparse=shparse_parse_dollar
				;;
			\`)
				local subparse=shparse_parse_backtick
				;;
			\")
				local subparse=shparse_parse_double_quote
				;;
			\')
				local subparse=shparse_parse_single_quote
				;;
			"${OPENPAREN}")
				((++depth));
				((shppm__end+="${#BASH_REMATCH[0]}"))
				continue
				;;
			"${CLOSEPAREN}")
				((shppm__end+="${#BASH_REMATCH[0]}"))
				if ((depth))
				then
					((--depth))
					continue
				elif [[ "${1:shppm__end:1}" == ')' ]]
				then
					((++shppm__end))
					if is_variable "${2:-RESULT}"
					then
						eval "${2:-RESULT}=${1: ${5:-0}:shppm__end - ${5:-0}}"
					fi
					restore_BASH_REMATCH orig_rematch
					return
				else
					shppm__end=-1
					restore_BASH_REMATCH orig_rematch
					return
				fi
				;;
			*)
				shppm__end=-1
				restore_BASH_REMATCH orig_rematch
				return
				;;
		esac
		"${1}" 0 "${3}" "${4}" \
			$(("${shppm__end}" + ${#BASH_REMATCH[0]} - 1))
	done
}

shparse_parse_command_sub() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a command substitution from assumed $( to ending ).
	local -n shppcs__end="${4:-END}"
	shppcs__end=$(("${5:-0}" + 2))
}

shparse_parse_dollar() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Call the corresponding $* expression.
	# Note that $0-9 will be arguments to shparse_parse_dollar rather
	# than whatever input argument there was...

	# From man bash:
	# When braces are used, the matching ending brace is the first \} not
	# escaped by a backslash or within a quoted string, and not within an
	# embedded arithmetic expansion, command substitution, or parameter
	# expansion.
	
	case "${1: ${5:-0}}" in
		\$\'*)
			shparse_parse_ansi_c "${@}"
			;;
		\$[-*@#?!0-9$]*)
			if is_variable "${2:-RESULT}"
			then
				eval "${2:-RESULT}=\"${1: ${5:-0}:2}\""
			fi
			eval "${3:-BEG}"='"${5:-0}"'
			eval "${4:-END}"='$((${5:-0} + 2))'
			;;
		\$[a-zA-Z_]*)
			local orig_rematch=("${BASH_REMATCH[@]}")
			[[ "${1: ${5:-0}}" =~ \$[a-zA-Z_][a-zA-Z_0-9]* ]]
			if is_variable "${2:-RESULT}"
			then
				eval "${2:-RESULT}=\"${BASH_REMATCH[0]}\""
			fi
			eval "${3:-BEG}"='"${5:-0}"'
			eval "${4:-END}"='"$((${5:-0} + ${#BASH_REMATCH[0]}))"'
			restore_BASH_REMATCH orig_rematch
			;;
		'$"'*)
			# parse a locale-converted string..., forward to string parsing.
			shparse_parse_double_quote "${1}" 0 "${3}" "${4}" "$((${5:-0} + 1))"
			local -n shppd__end="${4:-END}"
			local -n shppd__beg="${3:-BEG}"
			if ((shppd__end >= 0 || shppd__beg == ${5:-0} + 1))
			then
				shppd__beg=${5:-0}
			fi
			;;
		"\$${OPENPAREN}${OPENPAREN}"*)
			shparse_parse_math "${@}"
			;;
		"\$${OPENPAREN}"*)
			shparse_parse_command_sub "${@}"
			;;
		"\$${OPENBRACE}"*)
			shparse_parse_parameter_expansion "${@}"
			;;
		*)
			# invalid dollar expr, just a raw dollar sign
			eval "${3:-BEG}"='"${5:-0}"'
			eval "${4:-END}"='"$((${5:-0}+1))"'
			if is_variable "${2:-RESULT}"
			then
				eval "${2:-RESULT}=$"
			fi
			;;
	esac
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	start_test() {
		TEST="${1}"
		echo "testing ${TEST}"
	}
	run_test() # <text> <evalresult> <beg> <end> <segment> [initial=0]
	{
		local out= beg end
		local text="${1}"
		local gteval="${2}"
		local gtbeg="${3}"
		local gtend="${4}"
		local rawtext="${5}"
		local start="${6}"

		"${TEST}" "${text}" out beg end ${start}
		if [[ -n "${gteval}" && "${out}" != "${gteval}" ]] \
			|| [[ -n "${gtbeg}"  && "${beg}" != ${gtbeg} ]] \
			|| [[ -n "${gtend}"  && "${end}" != ${gtend} ]] \
			|| [[ -n "${rawtext}" && ( end < 0 || "${text:beg:end-beg}" != "${rawtext}" ) ]] \
			|| [[ -n "${gtbeg}" && -n "${rawtext}" && "${end}" -ne $((${gtbeg} + ${#rawtext})) ]]
		then
			printf 'fail
			input: %s
			  evaled:
			    expect %q
			    got    %q
			  range:
			    expect "%3s" - "%3s"
			    got    "%3s" - "%3s"
			  segment:
			    expect %s
			    got    %s
			' "${text}" \
			"${gteval}" "${out}" \
			"${gtbeg}" "${gtend}" "${beg}" "${end}" \
			"${rawtext}" "${text:beg:end < 0 ? ${#text}-beg : end-beg}" | sed 's/\t\t\t//g'
		else
			echo pass
		fi
	}

	start_test shparse_parse_ansi_c
	run_test "what$'\\nhello'extra" $'\nhello' 4 '' "$'\\nhello'" 4
	run_test "what$'\\nhello" '' 4 -1 '' 4
	run_test "what$'\\nh\\'ello" '' 4 -1 '' 4
	run_test "what$'\\nh\\'ello'" $'\nh\'ello' 4 '' "$'\\nh\\'ello'" 4


	start_test shparse_parse_single_quote
	run_test "b4'this is some string\\'extra" 'this is some string\' 2 '' "'this is some string\\'" 2
	run_test "'incomplete" '' '' -1 ''

	start_test shparse_parse_double_quote
	run_test '"this is a string"' 'this is a string' 0 18 '"this is a string"'
	run_test '"this is a string' '' 0 -1 ''
	run_test '"this is \"a\" str\${}ing" extra data' 'this is "a" str${}ing' 0 26 '"this is \"a\" str\${}ing"'

	run_test 'a"my home is at $HOME" extra data' "my home is at $HOME" 1 22 '"my home is at $HOME"' 1
	run_test 'a"my $-home is at $HOME" extra data' "my $-home is at $HOME" 1 24 '"my $-home is at $HOME"' 1
	run_test '"ansic $'"'this'"' is not expanded." f' "ansic \$'this' is not expanded." 0 32 '"ansic $'"'this'"' is not expanded."'

	run_test '"something `uname -a` yea"extra' 'something '"$(uname -a)"' yea' 0 26 '"something `uname -a` yea"'
	run_test '"${unknown:-${HOME}}"' "${HOME}" 0 21 '"${unknown:-${HOME}}"'
	run_test '"there are $((5 + 2)) penguins"' 'there are 7 penguins' 0 31 '"there are $((5 + 2)) penguins"'

	start_test shparse_parse_dollar
	# ansi_c dollar
	run_test "what$'\\nhello'extra" $'\nhello' 4 '' "$'\\nhello'" 4
	run_test "what$'\\nhello" '' 4 -1 '' 4
	run_test "what$'\\nh\\'ello" '' 4 -1 '' 4
	run_test "what$'\\nh\\'ello'" $'\nh\'ello' 4 '' "$'\\nh\\'ello'" 4
	run_test '$-' "$-" 0 2 '$-'
	run_test '$HOME extra' "$HOME" 0 5 '$HOME'
	run_test '$HOME!notvalid' "$HOME" 0 5 '$HOME'
	run_test '$%not a $ expansion' '$' 0 1 '$'

	start_test shparse_parse_backtick
	run_test 'hello`echo \\\`$HOME\\\$HOME\\\a`' \`${HOME}\$HOME\\a 5 33 '`echo \\\`$HOME\\\$HOME\\\a`' 5
	run_test 'hello`echo "incomplete string`' '' 11 -1 '' 5

	start_test shparse_parse_parameter_expansion
	run_test '${HOME}' "${HOME}" 0 7 '${HOME}'
	run_test '${unknown:-${HOME}}' "${HOME}" 0 19 '${unknown:-${HOME}}'
	run_test '${unknown:-${HOME' '' 11 -1 ''
	run_test ' ${custom_pwd:-`bash -c "echo hello"`}' "hello" 1 38 '${custom_pwd:-`bash -c "echo hello"`}' 1
	run_test ' ${custom_pwd:-`pwd}' '' 15 -1 '' 1
	run_test '${notexist:-"astring"'\''singlestr'\''}' "astringsinglestr" 0 33 '${notexist:-"astring"'\''singlestr'\''}'

	start_test shparse_parse_math
	run_test '$((1 + 2))' '3' 0 10 '$((1 + 2))'
	run_test '$(((1+2) * 3 + 4))' '13' 0 18 '$(((1+2) * 3 + 4))'
	run_test '$(((1+2) * (3 + 4)))' '21' 0 20 '$(((1+2) * (3 + 4)))'
	run_test '$(((1+2) * (3 + 4))' '' 0 -1 ''

fi
