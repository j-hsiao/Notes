"Automatically add closing round/square/curly brackets.
"Closing brackets only works when the cursor is on whitespace
"or a closing bracket of any kind.

"Opening char handling
let s:close_braces = {}
function! s:Prebrace(chars)
	"Insert an opening brace char if eol, whitespace, or closing brace
	if !get(s:close_braces, bufnr(), 1)
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
inoremap <expr> <silent> ( <SID>Prebrace("()")
inoremap <expr> <silent> [ <SID>Prebrace("[]")
inoremap <expr> <silent> { <SID>Prebrace("{}")

"Closing char handling
function! s:Postbrace(char)
	"Insert an opening brace char if eol, whitespace, or closing brace
	if !get(s:close_braces, bufnr(), 1)
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
inoremap <expr> <silent> ) <SID>Postbrace(")")
inoremap <expr> <silent> ] <SID>Postbrace("]")
inoremap <expr> <silent> } <SID>Postbrace("}")

function! s:ToggleCloseBrace()
	let bnum = bufnr()
	let s:close_braces[bnum] = 1 - get(s:close_braces, bnum, 1)
	echo "Autoclose brackets: " . s:close_braces[bnum]
endfunction

nnoremap <C-K>] :call <SID>ToggleCloseBrace()<CR>
