"Automatically add closing brace/paren when opening paren/brace. Open
"paren/brace only added if on whitespace or eol, or closing brace.
"Otherwise, it can be annoying if you're trying to add braces around
"something that has already been typed

"Opening char handling

let s:close_braces = 1
function! s:Prebrace(chars)
	"Insert an opening brace char if eol, whitespace, or closing brace
	if !s:close_braces
		return a:chars[0]
	endif
	let curidx = col('.')-1
	let curline = getline('.')
	if curidx == len(curline) || curline[curidx] =~ '\s' || curline[curidx] =~ '[)}\]]'
		if v:version > 801
			return a:chars . "\<Cmd>call cursor('.', " . (curidx+2) . ")\<CR>"
		else
			if curidx == len(curline)
				return a:chars[0] . "\<C-V>" . a:chars[1] . "\<C-O>i"
			else
				return a:chars . "\<C-O>h"
			endif
		endif
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
	if !s:close_braces
		return a:char
	endif
	let curidx = col('.')-1
	let curline = getline('.')
	if curline[curidx] == a:char
		if v:version > 801
			if curidx == len(curline)-1
				return "\<Cmd>call cursor('.', " . (len(curline)+1) . ")\<CR>"
			else
				return "\<Cmd>norm l\<CR>"
			endif
		else
			if curidx == len(curline)-1
				return "\<C-O>A"
			else
				return "\<C-O>l"
			endif
		endif
	else
		return a:char
	endif
endfunction
inoremap <expr> <silent> ) <SID>Postbrace(")")
inoremap <expr> <silent> ] <SID>Postbrace("]")
inoremap <expr> <silent> } <SID>Postbrace("}")

function! s:ToggleCloseBrace()
	let s:close_braces = 1 - s:close_braces
	echo "Autoclose braces: " . s:close_braces
endfunction

nnoremap <C-K>] :call <SID>ToggleCloseBrace()<CR>
