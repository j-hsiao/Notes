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
let s:closing = '\m[]'
let s:opening = '\m[]'

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

"Dict mapping closing char to opening char.
let s:rpairs = {}

"Insert opening character with [], {}, () in mind.
"These are inserted when following characters are non-words
"and non-opening char for pairs.
"or non-existent
function s:OpenPair(char1, char2)
	if !get(s:complete_pair, bufnr('%'), 1)
		return a:char1
	endif
	let nxt = strpart(getline('.'), col('.')-1, 1)
	if nxt !~ '\w' && nxt !~ s:opening
		return a:char1 . a:char2 . "\<Left>"
	else
		return a:char1
	endif
endfunction

"Put the ending character or skip over it if currently on it.
"It would be possible to search before to see if there's a corresponding
"starting char but I think too much hassle, not enough worth.
function s:ClosePair(char)
	if !get(s:complete_pair, bufnr('%'), 1)
		return a:char
	endif
	if strpart(getline('.'), col('.')-1, 1) == a:char
		return "\<Right>"
	else
		return a:char
	endif
endfunction


"Insert quotes.
"Only automatically pair quotes if cursor is surrounded by one of:
"space, blank ([{,}])
"ex.
"| = cursor insertion position
" hello|    -> single
" hello |   -> paired
" call(|)   -> paired
" mydict[|] -> paired
function s:SamePair(char)
	if !get(s:complete_pair, bufnr('%'), 1)
		return a:char
	endif
	let curline = getline('.')
	let curcol = col('.')
	let after = strpart(curline, curcol-1, 1)
	if after == a:char && (curcol == 1 || strpart(curline, curcol-2, 1) != '\')
		return "\<Right>"
	elseif after !~ '\S' || after =~ s:closing
		if strpart(curline, curcol-3, 2) == repeat(a:char, 2)
			let before = strpart(curline, curcol-4, 1)
			if before !~ '[^({[[:space:]=,]' && after !~ '[^\])},[:space:]]'
				return repeat(a:char, 4) . repeat("\<Left>", 3)
			endif
		endif
		let before = strpart(curline, curcol-2, 1)
		if before !~ '[^({[[:space:]=,]' && after !~ '[^\])},[:space:]]'
			return a:char . a:char . "\<Left>"
		endif
	endif
	return a:char
endfunction

"Save current state to analyze after a change.
"key should be a string representing the key to press <> notation
function! s:AutopairPreRmL(key)
	let s:hold = [line('.'), strpart(getline('.'), 0, col('.')-1)]
	execute substitute(
		\ 'return "<Plug>AutopairPreFallback' . a:key . ';<Plug>AutopairPostRmL;"',
		\ '<', '\\<', 'g')
endfunction

"Expect the removal to be to the left of original cursor position.
function! s:AutopairPostRmL()
	let [lnum, prestr] = s:hold
	if line('.') == lnum
		let curline = getline('.')
		let curpre = strpart(curline, 0, col('.')-1)
		let curpost = strpart(curline, col('.')-1)
		if curpre == strpart(prestr, 0, strlen(curpre))
			let preidx = strlen(prestr)-1
			let endidx = col('.') - 2
			let postidx = 0
			let target = get(s:rpairs, strpart(curpost, postidx, 1), '')
			while endidx < preidx && target != ''
				if strpart(prestr, preidx, 1) == target
					let postidx += 1
					let target = get(s:rpairs, strpart(curpost, postidx, 1), '')
				endif
				let preidx -= 1
			endwhile
			return repeat("\<Del>", postidx)
		endif
	endif
	return ''
endfunction
inoremap <expr> <Plug>AutopairPostRmL; <SID>AutopairPostRmL()

execute jhsiaomapfallback#CreateFallback('<Plug>AutopairPreFallbackBS;', '<BS>', 'i')
execute jhsiaomapfallback#CreateFallback('<Plug>AutopairPreFallbackC-H;', '<C-H>', 'i')
execute jhsiaomapfallback#CreateFallback('<Plug>AutopairPreFallbackC-W;', '<C-W>', 'i')
execute jhsiaomapfallback#CreateFallback('<Plug>AutopairPreFallbackC-U;', '<C-U>', 'i')
imap <expr> <BS> <SID>AutopairPreRmL("BS")
imap <expr> <C-H> <SID>AutopairPreRmL("C-H")
imap <expr> <C-W> <SID>AutopairPreRmL("C-W")
imap <expr> <C-U> <SID>AutopairPreRmL("C-U")

"Register a pair of opening and closing chars for completion.
"These should be using <> notation if applicable.
function s:RegisterPair(char1, char2)
	let cmd = 'let s:rpairs[' . json_encode(a:char2) . '] = ' . json_encode(a:char1)
	execute substitute(cmd, '<', '\\<', 'g')
	if a:char1 == a:char2
		let quoted = substitute(json_encode(a:char1), '<', '\\<', 'g')
		execute 'inoremap <expr> ' . a:char1 . ' <SID>SamePair(' . quoted . ')'
	else
		let s:closing = join([
			\ strpart(s:closing, 0, strlen(s:closing)-1),
			\ escape(a:char2, ']'), ']'], '')
		let q1 = substitute(json_encode(a:char1), '<', '\\<', 'g')
		let q2 = substitute(json_encode(a:char2), '<', '\\<', 'g')
		execute 'inoremap <expr> ' . a:char1 . ' <SID>OpenPair(' . q1 . ', ' . q2 . ')'
		execute 'inoremap <expr> ' . a:char2 . ' <SID>ClosePair(' . q2 . ')'
	endif
	let s:opening = join([
		\ strpart(s:opening, 0, strlen(s:opening)-1),
		\ escape(a:char1, ']'), ']'], '')
endfunction

"call <SID>RegisterPair('[', ']')
command! -nargs=+ RegisterPair call <SID>RegisterPair(<f-args>)
RegisterPair [ ]
RegisterPair ( )
RegisterPair { }
RegisterPair " "
RegisterPair ' '

function s:ToggleCompletePair()
	let newval = 1 - get(s:complete_pair, bufnr('%'), 1)
	let s:complete_pair[bufnr('%')] = newval
	echo "Complete pairs: " . newval
	return ''
endfunction

inoremap <expr> <Plug>AutopairToggleCompletePair; <SID>ToggleCompletePair()
nnoremap <expr> <Plug>AutopairToggleCompletePair; <SID>ToggleCompletePair()
if !hasmapto('<Plug>AutopairToggleCompletePair;', 'i')
		\ && maparg('<Leader>]', 'i') == ''
	imap <Leader>] <Plug>AutopairToggleCompletePair;
endif
if !hasmapto('<Plug>AutopairToggleCompletePair;', 'n')
		\ && maparg('<Leader>]', 'n') == ''
	nmap <Leader>] <Plug>AutopairToggleCompletePair;
endif
