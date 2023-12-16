"Automatically add paired items.


"if exists("g:loaded_autopair")
"	finish
"endif
"let g:loaded_autopair = 1


"Save whether or not to complete pairs per buffer.
let s:complete_pair = {}

"Insert opening character.  If the cursor is not followed
"by alpha-numeric character, insert the closing character
"as well.
function s:OpenPair(char1, char2)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char1
	endif
	let idx = col('.') - 1
	let curline = getline('.')
	if idx == strlen(curline) || curline[idx] !~ '\w'
		return a:char1 . a:char2 . "\<Left>"
	else
		return a:char1
endfunction

"Put the ending character or skip over it if currently on it.
function s:EndPair(char)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char
	endif
	let idx = col('.') - 1
	let curline = getline('.')
	if idx == strlen(curline) || curline[idx] != a:char
		return a:char
	else
		return "\<Right>"
	endif
endfunction

function s:SamePair(char)
	if !get(s:complete_pair, bufnr(), 1)
		return a:char
	endif
	let idx = col('.') - 1
	let curline = getline('.')

	let prechar = ''
	let postchar = ''
	if idx < strlen(curline)
		let postchar = curline[idx]
	endif
	if idx > 0
		let prechar = curline[idx-1]
	endif

	if postchar == a:char
		return "\<Right>"
	elseif prechar =~ '\s' || prechar == ''
		if postchar =~ '\s' || postchar == ''
			return a:char . a:char . "\<Left>"
		endif
	endif
	return a:char
endfunction


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
