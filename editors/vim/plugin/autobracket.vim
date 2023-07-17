"Automatically add closing round/square/curly brackets.
"Closing brackets only works when the cursor is on whitespace
"or a closing bracket of any kind.

"More convenient to remove an auto-closed char in the case
"where it is undesired.
inoremap <C-L> <Del>

"Opening char handling
let s:close_brackets = {}
function! s:Prebracket(chars)
	"Insert an opening bracket char if eol, whitespace, or closing bracket
	if !get(s:close_brackets, bufnr(), 1)
		return a:chars[0]
	endif
	let curidx = col('.')-1
	let curline = getline('.')
	if curidx == len(curline) || curline[curidx] =~ '\s' || curline[curidx] =~ '[)}\]]'
		return a:chars . "\<Left>"
	else
		return a:chars[0]
	endif
endfunction
inoremap <expr> <silent> ( <SID>Prebracket("()")
inoremap <expr> <silent> [ <SID>Prebracket("[]")
inoremap <expr> <silent> { <SID>Prebracket("{}")

"Closing char handling
function! s:Postbracket(char)
	"Insert an opening bracket char if eol, whitespace, or closing bracket
	if !get(s:close_brackets, bufnr(), 1)
		return a:char
	endif
	let curidx = col('.')-1
	let curline = getline('.')
	if curline[curidx] == a:char
		return "\<Right>"
	else
		return a:char
	endif
endfunction
inoremap <expr> <silent> ) <SID>Postbracket(")")
inoremap <expr> <silent> ] <SID>Postbracket("]")
inoremap <expr> <silent> } <SID>Postbracket("}")



function! s:RmBracket()
	let curline = getline('.')
	let idx = col('.')-1
	if len(curline) && idx > 0
		let check = curline[idx-1:idx]
		if check == '[]' || check == '()' || check == '{}'
			return "\<BS>\<Del>"
		endif
	endif
	return "\<BS>"
endfunction

inoremap <expr> <BS> <SID>RmBracket()

function! s:ToggleClosebracket()
	let bnum = bufnr()
	let s:close_brackets[bnum] = 1 - get(s:close_brackets, bnum, 1)
	echo "Autoclose brackets: " . s:close_brackets[bnum]
endfunction

nnoremap <C-K>] :call <SID>ToggleClosebracket()<CR>
