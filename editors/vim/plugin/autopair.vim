"Automatically add paired items.
"
"Some characters are usually paired.  For example, [ is usually paired
"with ] when indexing or ( is usually paired with ).  Automatically
"adding the second pair character can be useful to help reduce
"mismatched pairs.  However, always adding the pair might not be very
"useful.  Some characters are paired identically like " or '.
"
"Pairing can be explicitly avoided by using <C-V><char> where char is
"the opening char of the pair.

"if exists("g:loaded_autopair")
"	finish
"endif
"let g:loaded_autopair = 1


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

"Insert opening character with [], {}, () in mind.
"These would usually be inserted at end of line or
"when there are no word-like characters right after.
function s:OpenPair(char1, char2)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char1
	endif
	let [before, after] = s:CursorSplit(1)
	if after == '' || after !~ '\w'
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
	let [before, after] = s:CursorSplit(2)
	if after[0] == a:char
		return "\<Right>"
	elseif after == '' || after !~ '\w'
		if before == repeat(a:char, 2)
			"python """ or '''
			return repeat(a:char, 4) . repeat("\<Left>", 3)
		else
			let before = strpart(before, strlen(before)-1, 1)
			if before == '' || before !~ '\w'
				return a:char . a:char . "\<Left>"
			endif
		endif
	endif
	return a:char
endfunction

function CreateFallback(name, k, mode)
	let dct = maparg(a:k, a:mode, v:false, v:true)
	if len(dct)
"		let mpcmd = a:mode
"		if dct['noremap']
"			let mpcmd = mpcmd . 'nore'
"		endif
"		let mpcmd = mpcmd . 'map '
"		if dct['expr']
"			let mpcmd = mpcmd . '<expr> '
"		endif
"		let rhs = substitute(dct['rhs'], '<sid>', '<SNR>' . dct['sid'] . '_', 'g')
"		let mpcmd = mpcmd . a:name . ' ' . rhs
"		execute mpcmd

		let dct['lhs'] = a:name
		execute "let dct['lhsraw'] = \"" . escape(a:name, '"<\') . '"'
		let dct['rhs'] = substitute(dct['rhs'], '<SID>', '<SNR>' . dct['sid'] . '_', 'g')
		call mapset('i', v:false, dct)
	else
		" no prior mapping, just map to the key itself.
		execute 'inoremap ' . name . ' ' . a:k
	endif
endfunction

let s:pairs = []
function s:IRemovePairDispatch()
	if get(s:complete_pair, bufnr(), 1)
		let curidx = col('.') - 1
		let curpair = strpart(getline('.'), col('.') - 2, 2)
		for item in s:pairs
			if item == curpair
				return "\<Plug>\<Plug>AutopairIRemovePairAction"
			endif
		endfor
	endif
	return "\<Plug>\<Plug>AutopairIRemovePairFallback"
endfunction

call CreateFallback('<Plug><Plug>AutopairIRemovePairFallback', '<BS>', 'i')
inoremap <Plug><Plug>AutopairIRemovePairAction <BS><Del>
imap <expr> <Plug>AutopairIRemovePair <SID>IRemovePairDispatch()
imap <BS> <Plug>AutopairIRemovePair
imap <C-H> <Plug>AutopairIRemovePair

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

inoremap <expr> <Plug>AutopairToggleCompletePair <SID>ToggleCompletePair()
if !hasmapto('<Plug>AutopairToggleCompletePair', 'i')
		\ && maparg('<Leader>]', 'i') == ''
	imap <Leader>] <Plug>AutopairToggleCompletePair
endif


