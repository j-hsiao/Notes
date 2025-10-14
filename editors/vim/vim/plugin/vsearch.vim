"Search the highlighted text
function! s:VisualSearch(chr)
	let col1 = col('v')
	let col2 = col('.')
	if col2 < col1
		let [col1,col2] = [col2, col1]
	endif
	let col1 -= 1
	let query = strpart(getline('.'), col1, col2-col1)
	return "\<Esc>" . a:chr . '\V' . escape(query, '\/') . "\<CR>"
endfunction

if maparg("*", 'v') == ''
	vnoremap <expr> * <SID>VisualSearch('/')
endif
if maparg("#", 'v') == ''
	vnoremap <expr> # <SID>VisualSearch('?')
endif
