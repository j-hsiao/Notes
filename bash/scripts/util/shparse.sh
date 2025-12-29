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
# [end]: The variable name to store the ending position (exclusive).
#        That is to say, ${text:begin:end-begin} will be the parsed expression.
#        If the expression is incomplete, then end will be -1.
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


[[ "${BASH_SOURCE[0]}" != "${0}" ]] && declare -Fp shparse_parse_expr &>/dev/null && (($# == 0)) && return
. "${BASH_SOURCE[0]%"${BASH_SOURCE[0]##*/}"}restore_rematch.sh"

# vim brace/paren matching gets messed up
# when there are many strings/escapes of (){}
# maybe use an alternative so that vim % can still find the
# matching {} for function bodies.


# (: 0x28
# ): 0x29
# {: 0x7b
# }: 0x7d
# [: 0x5b
# ]: 0x5d

is_output() # <varname>
{
	# Success if is variable name, else error.
	# NOTE: only checks the first character
	# because the output could also be an expr
	# like arrayvar[idx] or something which is
	# valid to assign to, but is not a variable name.
	local orig_rematch=("${BASH_REMATCH[@]}")
	trap 'restore_BASH_REMATCH orig_rematch; trap - RETURN' RETURN
	[[ "${1}" =~ ^[a-zA-Z_][a-zA-Z_0-9]*(\[.*\])?$ ]]
}

shparse_parse_expr() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <Text> as a single expr indicated by <text>[initial]
	case "${1: ${5:-0}:1}" in
		\$)
			local subparse=shparse_parse_dollar
			;;
		\")
			local subparse=shparse_parse_double_quote
			;;
		\')
			local subparse=shparse_parse_single_quote
			;;
		\`)
			local subparse=shparse_parse_backtick
			;;
		$'\x28')
			local subparse=shparse_parse_paren
			;;
		*)
			local subparse=shparse_parse_word
			;;
	esac
	"${subparse}" "${@}"
}

shparse_parse_generic() # <pattern> <beginning> <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Generic Parser.  Parse <text> starting at <initial>.
	# <pattern> will be the regex pattern used to match <text>.
	# Pattern should contain at least 2 groups.  The last group should
	# be the group of ending patterns to end the parsing.  The second to
	# last should be sub-expression patterns to start sub-expression parsing.
	# <beginning> is the number of characters that starts this expression.
	# 4-7 matches 2-5 for the general stand-alone parser arguments.

	# local indent
	# printf -v indent "%${#BASH_SOURCE[@]}s" ''
	# printf "${indent}"'PARSING GENERIC from %d\n' "${7:-0}"
	# printf "${indent}"'  "%s"\n' "${3}"
	# printf "${indent}"'  %s\n' "${1}"

	local orig_rematch=("${BASH_REMATCH[@]}")
	trap 'restore_BASH_REMATCH orig_rematch; trap - RETURN' RETURN
	local -n shppg__end="${6:-END}"
	shppg__end=$((${7:-0} + ${2}))
	while [[ "${3:shppg__end}" =~ ^${1} ]]
	do
		# printf "${indent}"'  regex matched\n'
		# printf "${indent}"'    "%s"\n' "${BASH_REMATCH[@]}"
		if [[ -n "${BASH_REMATCH[-2]}" ]]
		then
			# printf "${indent}    subexpression: %s\n" \
			# 	"${3: shppg__end + ${#BASH_REMATCH[0]} - ${#BASH_REMATCH[-2]}}"
			shparse_parse_expr "${3}" 0 "${5}" "${6}" \
				$((shppg__end + ${#BASH_REMATCH[0]} - ${#BASH_REMATCH[-2]}))
			if ((shppg__end < 0))
			then
				return
			fi
		else
			((shppg__end+="${#BASH_REMATCH[0]}"))
			eval "${5:-BEG}=${7:-0}"
			if is_output "${4:-RESULT}"
			then
				eval "${4:-RESULT}=${3: ${7:-0}:shppg__end - ${7:-0}}"
			fi
			return
		fi
	done
	# printf "%${#BASH_SOURCE[@]}s  regexp match failed\\n" ''

	eval "${5:-BEG}=${7:-0}"
	shppg__end=-1
	return
}

shparse_parse_ansi_c() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as ansi-c quote from assumed $' until an ending '.
	shparse_parse_generic '(\\.|[^'\''\\])*()('\'')' 2 "${@}"
}

shparse_parse_single_quote() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a single-quote string from assumed ' to ending '.

	# From man bash:
	# Enclosing characters in single quotes preserves the literal value
	# of each character within the quotes.  A single quote may not occur
	# between single quotes, even when preceded by a backslash.
	# simple, just find the next single quote
	shparse_parse_generic "[^']*()(')" 1 "${@}"
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

	# valid subexpressions:
	# backtick, $ expressions (except ansi C)
	shparse_parse_generic '(\\.|[^$"`\\]|\$'\'')*((\$[^"]|`)|(\$"|"))' 1 "${@}"
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
	if [[ "${1: ${5:-0}}" =~ ^\`(\\.|[^\\\`])*\` ]]
	then
		local region="${1:0:${5:-0}+${#BASH_REMATCH[0]}-1}"
		local tickfix=1
	else
		local region="${1}"
		local tickfix=0
	fi
	# Still need to parse even if does not match in case there are
	# any subexprs that are incomplete.
	shparse_parse_generic '(\\.|[^$"'\''\\])*((\$|"|'\'')|($))' 1 "${region}" 0 "${@:3}"

	local -n shppbt__end="${4:-END}"
	if ((shppbt__end >= 0))
	then
		eval "${3:-BEG}="'"${5:-0}"'
		if ((tickfix))
		then
			((++shppbt__end))
			if is_output "${2:-RESULT}"
			then
				eval "${2:-RESULT}=${1: ${5:-0} : shppbt__end - ${5:-0}}"
			fi
		else
			shppbt__end=-1
		fi
	fi
	restore_BASH_REMATCH orig_rematch
}

shparse_parse_parameter_expansion() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a parameter expansion from assumed ${ to ending }.
	shparse_parse_generic '(\\.|[^\\$`"'\'$'\x7d''])*(([$`"'\''])|('$'\x7d''))' 2 "${@}"
}

shparse_parse_math() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as math expr from assumed $(( to ending ))
	# NOTE, in the bash manual, $[...] is deprecated and will be removed in
	# upcoming versions of bash, so for now, not going to bother implementing that.

	# The expression is treated as if it were within double quotes, but
	# a double quote inside the parentheses is not treated specially.
	# (quotes still need to be closed)
	# All tokens in the expression undergo parameter and  variable  ex‐
	# pansion, command substitution, and quote removal.  The result is
	# treated as the arithmetic expression to be evaluated.  Arithmetic
	# expansions may be nested.
	local sub=$'$"`\x28\''
	shparse_parse_generic '(\\.|[^'"${sub}"$'\x29''\\])*((['"${sub}"'])|(\'$'\x29\\\x29))' 3 "${@}"
	return
}
shparse_parse_paren() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a grouping from assumed ( to ending ).
	# This might occur as a group of commands, or possibly as parenthesized
	# expression within a arithmetic expansion.
	# Groupings don't actually evaluate into anything.
	local sub=$'$"`\'\x28'
	shparse_parse_generic '(\\.|[^'"${sub}"$'\x29''\\])*((['"${sub}])|("$'\\\x29))' 1 "${1}" 0 "${@:3}"
}

shparse_parse_command_sub() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> as a command substitution from assumed $( to ending ).
	# An incomplete command substitution will leave <begin> at the start of the
	# last incomplete word (word not followed by whitespace).  If all words
	# are complete, then begin will point to the empty word at the end of this
	# command substitution.

	local -n shppcs__end="${4:-END}"
	shppcs__end=$((${5-0} + 2))
	local orig_rematch=("${BASH_REMATCH[@]}")
	trap 'restore_BASH_REMATCH orig_rematch; trap - RETURN' RETURN
	while [[ "${1:shppcs__end:1}" = [^$'\x29'] ]]
	do
		shparse_parse_word "${1}" 0 "${3}" "${4}" "${shppcs__end}"
		if ((shppcs__end < 0))
		then
			return
		fi
	done
	if [[ "${1:shppcs__end:1}" = $'\x29' ]]
	then
		((++shppcs__end))
		if is_output "${2:-RESULT}"
		then
			eval "${2:-RESULT}=${1: ${5:-0}: shppcs__end - ${5:-0}}"
		fi
		eval "${3:-BEG}="'"${5:-0}"'
	else
		local -n shppcs__beg="${3:-BEG}"
		local lastword="${1:shppcs__beg}"
		[[ "${1:shppcs__beg}" =~ (\\.|[^$'\\"$\x29\x7d'\'"${IFS}"])*(["${IFS}"]*)$  ]]
		if [[ -n "${BASH_REMATCH[-1]}" ]]
		then
			shppcs__beg="${shppcs__end}"
		fi
		eval "${4:-END}=-1"
	fi
}

shparse_parse_dollar() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Call the corresponding $* expression.
	# Note that $0-9 will be arguments to shparse_parse_dollar rather
	# than whatever input argument there was so <out> would be the wrong
	# value in these cases

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
			if is_output "${2:-RESULT}"
			then
				eval "${2:-RESULT}=\"${1: ${5:-0}:2}\""
			fi
			eval "${3:-BEG}"='"${5:-0}"'
			eval "${4:-END}"='$((${5:-0} + 2))'
			;;
		\$[a-zA-Z_]*)
			local orig_rematch=("${BASH_REMATCH[@]}")
			[[ "${1: ${5:-0}}" =~ ^\$[a-zA-Z_][a-zA-Z_0-9]* ]]
			if is_output "${2:-RESULT}"
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
			if ((shppd__end >= 0)) && is_output "${2:-RESULT}"
			then
				eval "${2:-RESULT}=${1:shppd__beg:shppd__end}"
			fi
			;;
		$'$\x28\x28'*)
			shparse_parse_math "${@}"
			;;
		$'$\x28'*)
			shparse_parse_command_sub "${@}"
			;;
		$'$\x7b'*)
			shparse_parse_parameter_expansion "${@}"
			;;
		*)
			# invalid dollar expr, just a raw dollar sign
			eval "${3:-BEG}"='"${5:-0}"'
			eval "${4:-END}"='"$((${5:-0}+1))"'
			if is_output "${2:-RESULT}"
			then
				eval "${2:-RESULT}=$"
			fi
			;;
	esac
}

shparse_parse_word() # <text> [out=RESULT] [begin=BEG] [end=END] [initial=0]
{
	# Parse <text> As a bash word.  From assumed [^$IFS], to [$IFS]*
	local sub=$'$"\'\x28`'
	shparse_parse_generic '(\\.|[^'"${sub}"$'\x29''\\'"${IFS}"'])*(['"${sub}"']?)(['"${IFS}"']*|$)' 0 "${@}"
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
	run_test "a'incomplete" '' '' -1 '' 1

	start_test shparse_parse_double_quote
	run_test ' "this is a string"extra' 'this is a string' 1 19 '"this is a string"' 1
	run_test ' "this is a string' '' '' -1 '' 1
	run_test ' "this is \"a\" str\${}ing" extra data' 'this is "a" str${}ing' 1 27 '"this is \"a\" str\${}ing"' 1
	run_test ' "end of str\"' '' 1 -1 '' 1

	run_test 'a"my home is at $HOME" extra data' "my home is at $HOME" 1 22 '"my home is at $HOME"' 1
	run_test 'a"my $-home is at $HOME" extra data' "my $-home is at $HOME" 1 24 '"my $-home is at $HOME"' 1
	run_test ' "ansic $'"'this'"' is not expanded." f' "ansic \$'this' is not expanded." 1 33 '"ansic $'"'this'"' is not expanded."' 1

	run_test ' "something `uname -a` yea"extra' 'something '"$(uname -a)"' yea' 1 27 '"something `uname -a` yea"' 1
	run_test ' "${unknown:-${HOME}}"extra' "${HOME}" 1 22 '"${unknown:-${HOME}}"' 1
	run_test ' "there are $((5 + 2)) penguins"extra' 'there are 7 penguins' 1 32 '"there are $((5 + 2)) penguins"' 1

	run_test ' "This is incomplete $(echo command substitution' '' 36 -1 '' 1
	run_test ' "This is incomplete $(echo command substitution ' '' 49 -1 '' 1

	start_test shparse_parse_dollar
	# ansi_c dollar
	run_test " what$'\\nhello'extra" $'\nhello' 5 '' "$'\\nhello'" 5
	run_test " what$'\\nhello" '' 5 -1 '' 5
	run_test " what$'\\nh\\'ello" '' 5 -1 '' 5
	run_test " what$'\\nh\\'ello'extra" $'\nh\'ello' 5 '' "$'\\nh\\'ello'" 5
	run_test ' $-extra' "$-" 1 3 '$-' 1
	run_test ' $HOME extra' "$HOME" 1 6 '$HOME' 1
	run_test ' $HOME!notvalid' "$HOME" 1 6 '$HOME' 1
	run_test ' $%not a $ expansion' '$' 1 2 '$' 1
	run_test ' ${debian_chroot:+($debian_chroot)} extra' "${debian_chroot:+($debian_chroot)}" 1 35 '${debian_chroot:+($debian_chroot)}' 1

	start_test shparse_parse_backtick
	run_test 'hello`echo \\\`$HOME\\\$HOME\\\a`extra' \`${HOME}\$HOME\\a 5 33 '`echo \\\`$HOME\\\$HOME\\\a`' 5
	run_test 'hello`echo "incomplete string`extra' '' 11 -1 '' 5

	start_test shparse_parse_parameter_expansion
	run_test ' ${HOME}extra' "${HOME}" 1 8 '${HOME}' 1
	run_test ' ${unknown:-${HOME}}extra' "${HOME}" 1 20 '${unknown:-${HOME}}' 1
	run_test ' ${unknown:-${HOME' '' 12 -1 '' 1
	run_test ' ${custom_pwd:-`bash -c "echo hello"`}extra' "hello" 1 38 '${custom_pwd:-`bash -c "echo hello"`}' 1
	run_test ' ${custom_pwd:-`pwd}extra' '' 15 -1 '' 1
	run_test ' ${notexist:-"astring"'\''singlestr'\''}extra' "astringsinglestr" 1 34 '${notexist:-"astring"'\''singlestr'\''}' 1

	start_test shparse_parse_command_sub
	run_test ' $() ' '' 1 4 '$()' 1
	run_test ' $(echo hello) ' 'hello' 1 14 '$(echo hello)' 1
	run_test ' $(echo hello ) ' 'hello' 1 15 '$(echo hello )' 1
	run_test ' $(echo hello ' '' 14 -1 '' 1
	run_test ' $(echo hello' '' 8 -1 '' 1
	run_test ' $(echo "hello"' '' 8 -1 '' 1
	run_test ' $(echo "hello" ' '' 16 -1 '' 1
	run_test ' $(echo "hello' '' 8 -1 '' 1
	run_test ' $(echo "hello ' '' 8 -1 '' 1
	run_test ' $(echo "hello"\ ' '' 8 -1 '' 1

	start_test shparse_parse_math
	run_test ' $((1 + 2))' '3' 1 11 '$((1 + 2))' 1
	run_test ' $(((1+2) * 3 + 4))' '13' 1 19 '$(((1+2) * 3 + 4))' 1
	run_test ' $(((1+2) * (3 + 4)))' '21' 1 21 '$(((1+2) * (3 + 4)))' 1
	run_test ' $(((1+2) * (3 + 4))' '' 1 -1 '' 1
	run_test ' $(((1+2) * 1`date +%d`))' "$((3 * 1$(date +%d)))" 1 25 '$(((1+2) * 1`date +%d`))' 1

	start_test shparse_parse_word
	run_test ' hello${HOME}   whatever' "hello${HOME}" 1 16 'hello${HOME}   ' 1
	run_test ' "hello${HOME}"   whatever' "hello${HOME}" 1 18 '"hello${HOME}"   ' 1
	run_test ' "hello${HOME} "  whatever' "hello${HOME} " 1 18 '"hello${HOME} "  ' 1
	run_test ' "$HOME/Notes "  whatever' "${HOME}/Notes " 1 17 '"$HOME/Notes "  ' 1
	run_test ' "$HOME/some/path with "\(paren\)/"and trailspace "  whatever' "${HOME}/some/path with (paren)/and trailspace " 1 53 '"$HOME/some/path with "\(paren\)/"and trailspace "  ' 1
	run_test ' "${HOME}/someword/not/completed' '' 1 -1 '' 1
	run_test ' "${HOME}/someword/not/completed' '' 0 1 '' 0
	run_test ' $(some command substitution sub)' '' 29 32 '' 29

fi
