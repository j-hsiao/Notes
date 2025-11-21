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

	restore_BASH_REMATCH orig_rematch



	local -n shpppe__pos="${3:-POS}"
	shpppe__pos="${4:-0}"
	if [[ "${1:shpppe__pos:2}" != \${ ]]
	then
		if is_variable "${2-RESULT}"; then eval "${2:-RESULT}="; fi
		return
	fi
	((shpppe__pos+=2))
	while [[ "${shpppe__pos}" -lt ${#1} && "${1:shpppe__pos:1}" != } ]]
	do
		case "${1:shpppe__pos:1}" in
			\\)
				((++shpppe__pos))
				;;
			\$)
				shparse_parse_dollar_expr "${1}" 0 shpppe__pos "${shpppe__pos}"
				;;
			\')
				shparse_parse_single_quote "${1}" 0 shpppe__pos "${shpppe__pos}"
				;;
			\")
				shparse_parse_double_quote "${1}" 0 shpppe__pos "${shpppe__pos}"
				;;
			\`)
				shparse_parse_backtick "${1}" 0 shpppe__pos "${shpppe__pos}"
				;;
		esac
		((++shpppe__pos))
	done
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
		'$(('*)
			shparse_parse_math "${@}"
			;;
		'$('*)
			shparse_parse_command_sub "${@}"
			;;
		'${'*)
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
	run_test() # <test> <text> <evalresult> <beg> <end> <segment> [initial=0]
	{
		local out= beg end
		"${1}" "${2}" out beg end ${7}
		if [[ -n "${3}" && "${out}" != "${3}" ]] \
			|| [[ -n "${4}"  && "${beg}" != ${4} ]] \
			|| [[ -n "${5}"  && "${end}" != ${5} ]] \
			|| [[ -n "${6}" && ( end < 0 || "${2:beg:end-beg}" != "${6}" ) ]] \
			|| [[ -n "${4}" && -n "${6}" && "${end}" -ne $((${4} + ${#6})) ]]
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
			' "${2}" "${3}" "${out}" "${4}" "${5}" "${beg}" "${end}" "${6}" "${2:beg:end < 0 ? ${#2}-beg : end-beg}" | sed 's/\t\t\t//g'
		else
			echo pass
		fi
	}

	echo 'testing shparse_parse_ansi_c'
	run_test shparse_parse_ansi_c "what$'\\nhello'extra" $'\nhello' 4 '' "$'\\nhello'" 4
	run_test shparse_parse_ansi_c "what$'\\nhello" '' 4 -1 '' 4
	run_test shparse_parse_ansi_c "what$'\\nh\\'ello" '' 4 -1 '' 4
	run_test shparse_parse_ansi_c "what$'\\nh\\'ello'" $'\nh\'ello' 4 '' "$'\\nh\\'ello'" 4


	echo 'testing shparse_parse_single_quote'
	run_test shparse_parse_single_quote "b4'this is some string\\'extra" 'this is some string\' 2 '' "'this is some string\\'" 2
	run_test shparse_parse_single_quote "'incomplete" '' '' -1 ''

	echo 'testing shparse_parse_double_quote'
	run_test shparse_parse_double_quote '"this is a string"' 'this is a string' 0 18 '"this is a string"'
	run_test shparse_parse_double_quote '"this is a string' '' 0 -1 ''
	run_test shparse_parse_double_quote '"this is \"a\" str\${}ing" extra data' 'this is "a" str${}ing' 0 26 '"this is \"a\" str\${}ing"'

	run_test shparse_parse_double_quote 'a"my home is at $HOME" extra data' "my home is at $HOME" 1 22 '"my home is at $HOME"' 1
	run_test shparse_parse_double_quote 'a"my $-home is at $HOME" extra data' "my $-home is at $HOME" 1 24 '"my $-home is at $HOME"' 1
	run_test shparse_parse_double_quote '"ansic $'"'this'"' is not expanded." f' "ansic \$'this' is not expanded." 0 32 '"ansic $'"'this'"' is not expanded."'

	run_test shparse_parse_double_quote '"something `uname -a` yea"extra' 'something '"$(uname -a)"' yea' 0 26 '"something `uname -a` yea"'
	# TODO: add in dollar and backtick expr tests

	echo 'testing shparse_parse_dollar'
	# ansi_c dollar
	run_test shparse_parse_dollar "what$'\\nhello'extra" $'\nhello' 4 '' "$'\\nhello'" 4
	run_test shparse_parse_dollar "what$'\\nhello" '' 4 -1 '' 4
	run_test shparse_parse_dollar "what$'\\nh\\'ello" '' 4 -1 '' 4
	run_test shparse_parse_dollar "what$'\\nh\\'ello'" $'\nh\'ello' 4 '' "$'\\nh\\'ello'" 4
	run_test shparse_parse_dollar '$-' "$-" 0 2 '$-'
	run_test shparse_parse_dollar '$HOME extra' "$HOME" 0 5 '$HOME'
	run_test shparse_parse_dollar '$HOME!notvalid' "$HOME" 0 5 '$HOME'
	run_test shparse_parse_dollar '$%not a $ expansion' '$' 0 1 '$'

	echo 'testing shparse_parse_backtick'
	run_test shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a`' \`${HOME}\$HOME\\a 5 33 '`echo \\\`$HOME\\\$HOME\\\a`' 5
	run_test shparse_parse_backtick 'hello`echo "incomplete string`' '' 11 -1 '' 5
	# shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a' out pos 5 && [[ "${out}" = "\`$HOME\$HOME\\a" ]] && ((pos == 32)) && echo pass || echo fail


	# echo 'testing shparse_parse_dollar_expr'
	# shparse_parse_dollar_expr 'a$HOME$!)' out pos 1 && [[ "${out}" = "${HOME}" ]] && ((pos == 5)) && echo pass || echo fail
	# shparse_parse_dollar_expr 'a$HOME$!)' out pos 6 && [[ "${out}" = "$!" ]] && ((pos == 7)) && echo pass || echo fail
	# shparse_parse_dollar_expr 'a$HOME$!$)' out pos 8 && [[ "${out}" = '$' ]] && ((pos == 8)) && echo pass || echo fail
	# shparse_parse_dollar_expr 'a$HOME$!$)' out pos 0 && [[ "${out}" = '' ]] && ((pos == 0)) && echo pass || echo fail
	# shparse_parse_dollar_expr 'a$HOME$!$)$0' out pos 10 && [[ "${out}" = "${0}" ]] && ((pos == 11)) && echo pass || echo fail
	# shparse_parse_dollar_expr 'a$HOME$!$)$0$'"'\\n'" out pos 10 && [[ "${out}" = "${0}" ]] && ((pos == 11)) && echo pass || echo fail
	# shparse_parse_dollar_expr 'a$HOME$!$)$0$'"'\\n'" out pos 12 && [[ "${out}" = $'\n' ]] && ((pos == 16)) && echo pass || echo fail
fi
