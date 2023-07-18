"Easier Movement without exiting insert mode
"<C-O> would need to be repeatedly pressed.
"These mappings allow you to hold the movement as needed.
"home/end can just use C-O as normal.  Cursor movements start a new
"undoable edit anyways.
"
"Extra notes
"Any cursor movement not resulting from typing/deleting
"starts a new undoable edit.  There isn't really THAT much
"benefit from these. You can just <C-[> and then move
"wherever.  It is the same result.

let s:move = {}

function! Move(key, mv)
	if get(s:move, bufnr(), 1)
		exe 'return "\<' . a:mv . '>"'
	else
		exe 'return "\<C-' . a:key . '>"'
	endif
endfunction
inoremap <expr> <silent> <C-H> Move('H', 'Left')
inoremap <expr> <silent> <C-J> Move('J', 'Down')
inoremap <expr> <silent> <C-K> Move('K', 'Up')
inoremap <expr> <silent> <C-L> Move('L', 'Right')

inoremap <silent> <C-B> <S-Left>
inoremap <silent> <C-F> <S-Right>
inoremap <silent> <C-;> <Del>

function! s:ToggleMove()
	let bufn = bufnr()
	let s:move[bufn] = 1 - get(s:move, bufn, 1)
	echo "insert mode <C-HJKL> movement: " . s:move[bufn]
endfunction
nnoremap <C-K>h :call <SID>ToggleMove()<CR>

