#!/bin/bash


shparse_parse_ansi_c() # <text> [out] [pos=POS] [start=0]
{
	# Parse <text> as ansi-c quote $'...'.
	# Store the ending single quote in [pos] and the value in [out] if nonempty.
	# If the terminating single quote is not found, assume it is after <text>.
	# If ${text:start:2} != "$'", then out is empty and pos is start.
	local -n shppac__out="${2:-RESULT}"
	local -n shppac__pos="${3:-POS}"
	shppac__pos=${4:-0}
	if [[ "${1:shppac__pos:2}" != \$\' ]]
	then
		if ((${#2}))
		then
			shppac__out=
		fi
		return
	fi
	# https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html
	((shppac__pos+=2))
	while [[ "${shppac__pos}" -lt "${#1}" && "${1:shppac__pos:1}" != "'" ]]
	do
		if [[ "${1:shppac__pos:1}" = '\' ]]
		then
			case "${1:shppac__pos+1}" in
				a*|b*|e*|E*|f*|n*|r*|t*|v*|'\'*|"'"*|'"'*|'?'*)
					((++shppac__pos))
					;;
				# it seems like bash allows incomplete octal/unicode/hex, etc
				U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*)
					((shppac__pos += 9))
					;;
				U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*)
					((shppac__pos += 8))
					;;
				U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*)
					((shppac__pos += 7))
					;;
				U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*)
					((shppac__pos += 6))
					;;
				U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*|u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*)
					((shppac__pos += 4))
					;;
				U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*|u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*|x[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*|[0-7][0-7][0-7]*)
					((shppac__pos += 3))
					;;
				c?*|[0-7][0-7]*|x[0-9a-fA-F]*) # control-? sequence, partial octal, partial hex
					((shppac__pos += 2))
					;;
				[0-7])
					((++shppac__pos))
					;;
			esac
		fi
		((++shppac__pos))
	done
	# parsed as single ansi c quote, so should be safe to eval...
	if ((${#2}))
	then
		eval shppac__out="${1:${4#-0}:shppac__pos - ${4#-0}}'"
	fi
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

	local -n shppsq__out="${2:-RESULT}"
	local -n shppsq__pos="${3:-POS}"
	shppsq__pos="${4:-0}"
	if [[ "${1:shppsq__pos:1}" != "'" ]]
	then
		if ((${#2}))
		then
			shppsq__out=
		fi
		return
	fi
	((++shppsq__pos))
	while [[ "${shppsq__pos}" -lt "${#1}" && "${1:shppsq__pos:1}" != "'" ]]
	do
		((++shppsq__pos))
	done
	if ((${#2}))
	then
		shppsq__out="${1:${4:-0}+1:shppsq__pos - 1 - ${4:-0}}"
	fi
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


	local -n shppdq__out="${2:-RESULT}"
	local -n shppdq__pos="${3:-POS}"
	if ((${#2})); then shppdq__out=; fi
	shppdq__pos="${3:-0}"
	if [[ "${1:shppdq__pos:1}" != '"' ]]; then return; fi
	((++shppdq__pos))
	while [[ "${shppdq__pos}" -lt "${#1}" && "${1:shppdq__pos:1}" != '"' ]]
	do
		case "${1:shppdq__pos:1}" in
			'\')
				if [[ "${1:shppdq__pos+1:1}" = ['$`"\'$'\n'] ]]
				then
					if ((${#2})); then shppdq__out+="${1:shppdq__pos+1:1}"; fi
					((++shppdq__pos))
				fi
				;;
			'$')
				case "${1:shppdq__pos+1:1}" in
					'{')
						local shppdq__subval
						shparse_parse_param "${1}" shppdq__subval shppdq__pos "${shppdq__pos}"
						;;
					'(')
						if [[ "${1:shppdq__pos+2:1}" = '(' ]]
						then
							local shppdq__subval
							shparse_parse_mathsub "${1}" shppdq__subval shppdq__pos "${shppdq__pos}"
						else
							local shppdq__subval
							shparse_parse_commandsub "${1}" shppdq__subval shppdq__pos "${shppdq__pos}"
						fi
						;;
					[0-9])
						# nth argument
						((++shppdq__pos))
						;;
					*)
						if [[ "${1:shppdq__pos+1:1}" =~ [a-zA-Z_][a-zA-Z0-9_]* ]]
						then
							# variable without {}
							:
						fi
				esac
				;;
			'`')
				local shppdq__subval
				shparse_parse_backtick "${1}" shppdq__subval shppdq__pos "${shppdq__pos}"
				;;
			*)
				if (("${#2}")); then shppdq__out+="${1:shppdq__pos:1}"; fi
				;;
		esac
		((++shppdq__pos))
	done
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

	local -n shppbt__out="${2:-RESULT}"
	local -n shppbt__pos="${3:-POS}"
	shppbt__pos="${4:-0}"
	if [[ "${1:shppbt__pos:1}" != '`' ]]
	then
		if ((${#2}))
		then
			shppbt__out=
		fi
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
	if ((${#2}))
	then
		eval shppbt__out="${1:${4:-0}:shppbt__pos-${4:-0}}\`"
	fi
}

shparse_parse_param() # <text> [out=RESULT] [pos=POS] [start=0]
{
	# Parse <text> as a parameter substitution ${...}
	# Store the terminating } in [pos] and the value in [out]
	# If ${text:start:2} != '${', then out is empty and pos is start

	# From man bash:
	# When braces are used, the matching ending brace is the first `}' not
	# escaped by a backslash or within a quoted string, and not within an
	# embedded arithmetic expansion, command substitution, or parameter
	# expansion.
	local -n shppppm__out="${2:-RESULT}"
	local -n shppppm__pos="${3:-POS}"


}
shparse_parse_commandsub() # <text> [out=RESULT] [pos=POS] [start=0]
{
	# Parse <text> as a command substitution $(...)
	# Store the terminating ) in [pos] and the value in [out]
	# If ${text:start:3} != '$(', then out is empty and pos is start
	local -n shppcs__out="${2:-RESULT}"
	local -n shppcs__pos="${3:-POS}"
}
shparse_parse_mathsub() # <text> [out=RESULT] [pos=POS] [start=0]
{
	# Parse <text> as an arithmetic expansion $((...))
	# Store the terminating ) in [pos] and the value in [out]
	# If ${text:start:3} != '$((', then out is empty and pos is start
	local -n shppms__out="${2:-RESULT}"
	local -n shppms__pos="${3:-POS}"
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]]
then
	echo 'testing shparse_parse_ansi_c'
	shparse_parse_ansi_c "what$'\\nhello'extra" out pos 2 && [[ "${out}" = '' ]] && ((pos == 2)) && echo pass || echo fail
	shparse_parse_ansi_c "what$'\\nhello'extra" out pos 4 && [[ "${out}" = $'\nhello' ]] && ((pos == 13)) && echo pass || echo fail
	shparse_parse_ansi_c "what$'\\nhello" out pos 4 && [[ "${out}" = $'\nhello' ]] && ((pos == 13)) && echo pass || echo fail
	shparse_parse_ansi_c "what$'\\nh\\'ello" out pos 4 && [[ "${out}" = $'\nh\'ello' ]] && ((pos == 15)) && echo pass || echo fail

	echo 'testing shparse_parse_single_quote'
	shparse_parse_single_quote "'this is some string\\'extra" out pos && [[ "${out}" = 'this is some string\' ]] && ((pos == 21)) && echo pass || echo fail
	shparse_parse_single_quote "'incomplete" out pos && [[ "${out}" = 'incomplete' ]] && ((pos == 11)) && echo pass || echo fail
	shparse_parse_single_quote "'incomplete" out pos 1 [[ "${out}" = '' ]] && ((pos == 1)) && echo pass || echo fail

	echo 'testing shparse_parse_backtick'
	shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a`' out pos 0 && [[ "${out}" = '' ]] && ((pos == 0)) && echo pass || echo fail
	shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a`' out pos 5 && [[ "${out}" = "\`$HOME\$HOME\\a" ]] && ((pos == 32)) && echo pass || echo fail
	shparse_parse_backtick 'hello`echo \\\`$HOME\\\$HOME\\\a' out pos 5 && [[ "${out}" = "\`$HOME\$HOME\\a" ]] && ((pos == 32)) && echo pass || echo fail
fi
