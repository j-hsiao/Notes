"NOTE: <expr> mappings do not allow modifications to text.
"However, insert mode <C-R>= can modify text and may be a better choice
"than using <C-O>:call since restoring the position after the <C-O> may
"result in incorrect cursor placement after the <C-O> command is
"finished.

if get(g:, 'loaded_jhsiaoinsert', 0)
	finish
endif
let g:loaded_jhsiaoinsert = 1

"Insert text in current line while keeping cursor in same position
function! jhsiaoinsert#InsertText(text, bytepos)
	let curline = getline('.')
	let curpos = getpos('.')
	call setline('.', strpart(curline, 0, a:bytepos)
		\ . a:text . strpart(curline, a:bytepos))
	if a:bytepos < curpos[2]
		let curpos[2] += strlen(a:text)
		call setpos('.', curpos)
	endif
	return ''
endfunction

"Delete nbytes bytes from current line at bytepos position without
"changing the relative cursor position.
function! jhsiaoinsert#DeleteText(nbytes, bytepos)
	let curline = getline('.')
	let curpos = getpos('.')
	call setline('.', strpart(curline, 0, a:bytepos)
		\ . strpart(curline, a:bytepos + a:nbytes))
	if a:bytepos < curpos[2]
		let curpos[2] -= min([curpos[2]-(a:bytepos+1), a:nbytes])
		call setpos('.', curpos)
	endif
	return ''
endfunction
