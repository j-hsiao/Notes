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
#          value.  If there is an incomplete subexpression, then start will
#          point to its starting position.
# [end]: The variable name to store the ending position (exclusive) position.
#        That is to say, ${text:start:stop-start} will be the parsed expression.
#        if end exists, then it is the first character NOT in the parsed expression.
#        If the expression is incomplete, this will be -1.
# [initial]: The initial beginning position
#
# To avoid redundant checks, parsing functions assume that <text>
# starts with the corresponding characters for the target expression type.
#
# Example:
# 	${myvar:-${HO<Tab>
#
# 	This is incomplete so out will be empty if it was given.
# 	start will be 9
# 	count will be -1 (it was incomplete)
#
#

. "${BASH_SOURCE[0]%shparse.sh}restore_rematch.sh"

is_variable() # <varname>
{
	# Success if is variable name, else error.
	local orig=("${BASH_REMATCH[@]}")
	[[ "${1}" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]]
	restore_BASH_REMATCH orig
}

shparse_parse_ansi_c() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as ansi-c quote $'...'.  Assume <text> starts with $'
	eval "${3:-BEG}=${5:-0}"
	local orig_rematch=("${BASH_REMATCH[@]}")
	[[ "${1:2 + ${5:-0}}" =~ ^(\\.|[^\\\'])*\' ]]
	if [[ -n "${BASH_REMATCH[0]}" ]]
	then
		eval "${4:-END}=$((${5:-0} + 2 + "${#BASH_REMATCH[0]}"))"
		if is_variable "${2:-RESULT}"
		then
			eval "${2:-RESULT}=\$'${BASH_REMATCH[0]}"
		fi
	else
		eval "${4:-END}=-1"
	fi
	restore_BASH_REMATCH orig_rematch
}

shparse_parse_single_quote() # <text> [out] [pos=POS] [start=0]
{
	# Parse <text> as a single-quote string.
	# Store the ending single quote in [pos] and the value in [out] if nonempty.
	# If the terminating single quote is not found, assume it is after <text>.
	# If ${text:start:1} != "'", then out is empty and pos is start.

	# From man bash:
	# Enclosing characters in single quotes preserves the literal value
	# of each character within the quotes.  A single quote may not occur
	# between single quotes, even when preceded by a backslash.
	# simple, just find the next single quote
	eval "${3:-BEG}=${5:-0}"

	local orig_rematch=("${BASH_REMATCH[@]}")
	[[ "${1:${5:-0}+1}" =~ ^[^\']*\' ]]
	if [[ -n "${BASH_REMATCH[0]}" ]]
	then
		eval "${4:-END}=$((${#BASH_REMATCH[0]}+1+${5:-0}))"
		if is_variable "${2:-RESULT}"
		then
			eval "${2:-RESULT}='${BASH_REMATCH[0]}"
		fi
	else
		eval "${4:-END}=-1"
	fi
	restore_BASH_REMATCH orig_rematch
}

shparse_parse_double_quote() # <text> [out] [pos=POS] [start=0]
{
	# Parse <text> as a double-quote string.
	# Store the terminating double quote in [pos] and the value in [out] if nonempty.
	# If the terminating double quote is not found, assume it is after <text>.
	# If ${text:start:1} != '"', then out is empty and pos is start.

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

	local -n shppdq__pos="${3:-POS}"
	if is_variable "${2:-RESULT}"; then eval "${2:-RESULT}="; fi

	shppdq__pos="${3:-0}"
	if [[ "${1:shppdq__pos:1}" != '"' ]]; then return; fi
	((++shppdq__pos))
	while [[ "${shppdq__pos}" -lt "${#1}" && "${1:shppdq__pos:1}" != '"' ]]
	do
		case "${1:shppdq__pos:1}" in
			'\')
				if [[ "${1:shppdq__pos+1:1}" = ['$`"\'$'\n'] ]]
				then
					((++shppdq__pos))
				fi
				;;
			'$')
				# TODO double quote cannot activate ansi c quote
				# so parse_dollar_expr is wrong here...
				shparse_parse_dollar_expr "${1}" 0 shppdq__pos "${shppdq__pos}"
				;;
			'`')
				shparse_parse_backtick "${1}" 0 shppdq__pos "${shppdq__pos}"
				;;
			*)
				;;
		esac
		((++shppdq__pos))
	done
	# TODO eval from start to finish
	# subparses should not have output because
	# everything would need to be evaled anyways if this call requires output.
}

shparse_parse_backtick() # <text> [out] [pos=POS] [start=0]
{
	# Parse <text> backtick command substitution.
	# Store the terminating backtick in [pos] and the value in [out] if nonempty.
	# If ${text:start:1} != '`', then out is empty and pos is start

	# From man bash:
	# When the old-style backquote form of substitution is used,
	# backslash retains its literal meaning except when followed by $,
	# `, or \.  The first backquote not preceded by a backslash
	# terminates the command substitution.
	#
	# After some testing, it seems like backtick parsing is like this:
	# 1. Parse like a string
	# 2. eval the string
	#
	# ex: `echo '\`'`
	# -> echo '`'
	# -> `
	#
	# ex2: `echo \$\$`
	# -> echo $$
	# -> the pid of current process
	#
	# ex3: `echo \\\$\\\$`
	# -> echo \$\$
	# -> 2 literal dollar signs

	local -n shppbt__pos="${3:-POS}"
	shppbt__pos="${4:-0}"
	if [[ "${1:shppbt__pos:1}" != '`' ]]
	then
		if is_variable "${2:-RESULT}"; then eval "${2:-RESULT}="; fi
		return
	fi
	((++shppbt__pos))

	while [[ "${shppbt__pos}" -lt "${#1}" && "${1:shppbt__pos:1}" != '`' ]]
	do
		if [[ "${1:shppbt__pos:1}" = '\' && "${1:shppbt__pos+1:1}" = ['$\`'] ]]
		then
			((++shppbt__pos))
		fi
		((++shppbt__pos))
	done
	if is_variable "${2:-RESULT}"
	then
		eval "${2:-RESULT}=${1:${4:-0}:shppbt__pos-${4:-0}}\`"
	fi
}

shparse_parse_parameter_expansion() # <text> [out=RESULT] [pos=POS] [start=0]
{
	# Parse <text> as a parameter expansion ${...} expression.
	# Store the ending \} in [pos].
	# if <text> is not a parameter expansion, [out] is empty and [pos] = [start]
	# parse ${} expr
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


shparse_parse_dollar_expr() # <text> [out=RESULT] [pos=POS] [start=0]
{
	# Parse <text> as a $expr
	# Store the terminating character in [pos]
	# If it does not match any patterns, [out] is empty and [pos] = [start]

	# From man bash:
	# When braces are used, the matching ending brace is the first \} not
	# escaped by a backslash or within a quoted string, and not within an
	# embedded arithmetic expansion, command substitution, or parameter
	# expansion.
	local -n shppde__pos="${3:-POS}"
	shppde__pos="${4:-0}"

	case "${1:shppde__pos:2}" in
		\$\')
			shparse_parse_ansi_c "${@}"
			return
			;;
		'$*'|'$@'|'$#'|'$?'|'$-'|'$$'|'$!'|\$[0-9])
			# Special variable expansion
			if is_variable "${2:-RESULT}"; then eval "${2:-RESULT}=\"${1:shppde__pos:2}\""; fi
			((++shppde__pos))
			return
			;;
		\$[a-zA-Z_])
			# parse $varname expr
			local orig_rematch=("${BASH_REMATCH[@]}")
			[[ "${1:shppde__pos+1}" =~ ^([a-zA-Z_][a-zA-Z_0-9]*) ]]
			if is_variable "${2:-RESULT}"; then eval "${2:-RESULT}=\$${BASH_REMATCH[1]}"; fi
			((shppde__pos+="${#BASH_REMATCH[1]}"))
			restore_BASH_REMATCH orig_rematch
			return
			;;
		\$\{)
			shparse_parse_parameter_expansion "${@}"
			return
			;;
		'$(')
			if [[ "${1:shppde__pos+2:1}" = '(' ]]
			then
				# $((math expr))
				:
			else
				# $(command)
				:
			fi
			;;
		\$*)
			# ex echo $%
			if is_variable "${2:-RESULT}"; then eval "${2:-RESULT}='\$'"; fi
			return
			;;
		*)
			if is_variable "${2:-RESULT}"; then eval "${2:-RESULT}="; fi
			return
			;;
	esac
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	run_test() # <test> <text> <out> <beg> <end> <segment> [initial=0]
	{
		local out beg end
		"${1}" "${2}" out beg end ${7}
		if [[ -n "${3}" && "${out}" != "${3}" ]] \
			|| [[ -n "${4}"  && ${beg} != ${4} ]] \
			|| [[ -n "${5}"  && ${end} != ${5} ]] \
			|| [[ -n "${6}" && ( end < 0 || "${2:beg:end-beg}" != "${6}" ) ]] \
			|| [[ -n "${4}" && -n "${6}" && "${end}" -ne $((${4} + ${#6})) ]]
		then
			echo fail
			printf 'input: %s\n' "${2}"
			printf '  out: %q vs %q\n' "${out}" "${3}"
			printf '  range: %d - %d vs %s - %s\n' "${beg}" "${end}" "${4}" "${5}"
			printf '  segment: %s vs %s\n' "${2:beg:end-beg}" "${6}"
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

	# echo 'testing shparse_parse_backtick'
	# shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a`' out pos 0 && [[ "${out}" = '' ]] && ((pos == 0)) && echo pass || echo fail
	# shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a`' out pos 5 && [[ "${out}" = "\`$HOME\$HOME\\a" ]] && ((pos == 32)) && echo pass || echo fail
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
