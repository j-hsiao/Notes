"Automatically add paired items.
"
"Some characters are usually paired.  For example, [ is usually paired
"with ] when indexing or ( is usually paired with ).  Automatically
"adding the second pair character can be useful to help reduce
"mismatched pairs.  However, always adding the pair might not be very
"useful.  Some characters are paired identically like quotes.
"
"Pairing can be explicitly avoided by using <C-V><char> where char is
"the opening char of the pair.

if get(g:, 'loaded_autopair', 0)
	finish
endif
let g:loaded_autopair = 1

"Save whether or not to complete pairs per buffer.
let s:complete_pair = {}

"Split the current line by cursor position
function s:CursorSplit(length)
	let idx = col('.') - 1
	let curline = getline('.')
	if a:length
		return [strpart(curline, idx-a:length, a:length), strpart(curline, idx, a:length)]
	else
		return [strpart(curline, 0, idx), strpart(curline, idx)]
	endif
endfunction

let s:pairs = {}
let s:rpairs = {}

"Insert opening character with [], {}, () in mind.
"These would usually be inserted at end of line or
"when there are no word-like characters right after.
function s:OpenPair(char1, char2)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char1
	endif
	let [before, after] = s:CursorSplit(1)
	if after !~ '\w' || get(s:rpairs, after, '') != ''
		return a:char1 . a:char2 . "\<Left>"
	else
		return a:char1
	endif
endfunction

"Put the ending character or skip over it if currently on it.
"It would be possible to search before to see if there's a corresponding
"starting char but I think too much hassle, not enough worth.
function s:EndPair(char)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char
	endif
	let [before, after] = s:CursorSplit(1)
	if after == '' || after != a:char
		return a:char
	else
		return "\<Right>"
	endif
endfunction

"Insert opening and closing character when they are identical
"This is implemented with quoting in mind.
"Insert double when at end of line or surrounded by non-text/nothing.
"ex.
" hello|    -> single
" hello |   -> paired
" call(|)   -> paired
" mydict[|] -> paired
function s:SamePair(char)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char
	endif
	let [before, after] = s:CursorSplit(3)
	if after[0] == a:char
		return "\<Right>"
	elseif after == '' || after[0] !~ '\w'
		if strpart(before, strlen(before)-2, 2) == repeat(a:char, 2)
			\ && strpart(before, 0, strlen(before)-2) !~ '\S'
			" python docstring using double or single quotes.
			return repeat(a:char, 4) . repeat("\<Left>", 3)
		elseif strpart(before, strlen(before)-1, 1) !~ '\w'
			return a:char . a:char . "\<Left>"
		endif
	endif
	return a:char
endfunction

"Save current state to analyze after a change.
"key should be a string representing the key to press <> notation
function! s:AutopairPreRm(key)
	let s:hold = [line('.'), strpart(getline('.'), 0, col('.')-1)]
	execute substitute(
		\ 'return "<Plug>AutopairPreFallback' . a:key . ';<Plug>AutopairPostRm;"',
		\ '<', '\\<', 'g')
endfunction

function! s:AutopairPostRm()
	let [lnum, prestr] = s:hold
	if line('.') == lnum
		let curline = getline('.')
		let curpre = strpart(curline, 0, col('.')-1)
		let curpost = strpart(curline, col('.')-1)
		let idx = strlen(prestr)-1
		let endidx = strlen(curpre)-1
		let dcount = 0
		while endidx < idx
			let curchar = strpart(prestr, idx, 1)
			for pair in s:pairs
				if curchar == pair[0]
					\ && strpart(curpost, dcount, 1) == pair[1]
					let dcount += 1
					break
				endif
			endfor
			let idx -= 1
		endwhile
		return repeat("\<Del>", dcount)
	endif
	return ''
endfunction
inoremap <expr> <Plug>AutopairPostRm; <SID>AutopairPostRm()

execute mapfallback#CreateFallback('<Plug>AutopairPreFallback<C-H>;', '<C-H>', 'i')
execute mapfallback#CreateFallback('<Plug>AutopairPreFallback<C-W>;', '<C-W>', 'i')
execute mapfallback#CreateFallback('<Plug>AutopairPreFallback<C-U>;', '<C-U>', 'i')
imap <expr> <C-H> <SID>AutopairPreRm("<lt>C-H>")
imap <expr> <C-W> <SID>AutopairPreRm("<lt>C-W>")
imap <expr> <C-U> <SID>AutopairPreRm("<lt>C-U>")

"Convert a string to a quoted str.
"ex: 'a' -> "'a'"
"ex: <C-H> -> '"\<C-H>"'
"
"This means to get the actual key value, you can just
"execute 'let varname = ' . MapQuoted(char)
function s:MapQuoted(char)
	if strlen(a:char) > 1 && a:char[0] == '<'
		return '\"' . a:char . '"'
	elseif a:char == "'"
		return '"' . a:char . '"'
	else
		return "'" . a:char . "'"
	endif
endfunction

"Register a pair of opening and closing chars for completion.
"These should be chars as typed in a map command.
function s:RegisterPair(char1, char2)
	execute  'call add(s:pairs, ' . s:MapQuoted(a:char1) . ' . ' .  s:MapQuoted(a:char2) . ')'
	if a:char1 == a:char2
		execute 'inoremap <expr> ' . a:char1 . ' <SID>SamePair(' . s:MapQuoted(a:char1) . ')'
	else
		execute 'inoremap <expr> ' . a:char1 . ' <SID>OpenPair(' . s:MapQuoted(a:char1) . ', ' . s:MapQuoted(a:char2) . ')'
		execute 'inoremap <expr> ' . a:char2 . ' <SID>EndPair(' . s:MapQuoted(a:char2) . ')'
	endif
endfunction

"call <SID>RegisterPair('[', ']')
command! -nargs=+ RegisterPair call s:RegisterPair(<f-args>)
RegisterPair [ ]
RegisterPair ( )
RegisterPair { }
RegisterPair " "
RegisterPair ' '

function s:ToggleCompletePair()
	let newval = 1 - get(s:complete_pair, bufnr(), 1)
	let s:complete_pair[bufnr()] = newval
	echo "Complete pairs: " . newval
	return ''
endfunction

inoremap <expr> <Plug>AutopairToggleCompletePair; <SID>ToggleCompletePair()
if !hasmapto('<Plug>AutopairToggleCompletePair;', 'i')
		\ && maparg('<Leader>]', 'i') == ''
	imap <Leader>] <Plug>AutopairToggleCompletePair;
endif
