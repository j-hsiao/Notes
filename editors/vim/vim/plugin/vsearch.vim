"Search the highlighted text
function! s:VisualSearch(chr, useic)
	" chr: search direction '/'=forward, '?'=backward
	" useic: false = case sensitive, always exact
	"        true  = use the value of &g:ignorecase
	let ret = ["\<Esc>", a:chr, '\V']
	if a:useic && &g:ignorecase
		call add(ret, '\c')
	else
		call add(ret, '\C')
	endif
	let curmode=mode()
	if curmode ==# 'v'
		let col1 = col('v')
		let col2 = col('.')
		if col2 < col1
			let [col1,col2] = [col2, col1]
		endif
		let col1 -= 1
		call add(ret, escape(strpart(getline('.'), col1, col2-col1), '\/'))
	elseif curmode ==# 'V'
		call add(ret, escape(getline('.'), '\/'))
	else
		return "\<Esc>"
	endif
	call add(ret, "\<CR>")
	return join(ret, '')
endfunction

if maparg("*", 'v') == ''
	vnoremap <expr> * <SID>VisualSearch('/', v:true)
endif
if maparg("#", 'v') == ''
	vnoremap <expr> # <SID>VisualSearch('?', v:true)
endif

if maparg("<Leader>*", 'v') == ''
	vnoremap <expr> <Leader>* <SID>VisualSearch('/', v:false)
endif
if maparg("<Leader>#", 'v') == ''
	vnoremap <expr> <Leader># <SID>VisualSearch('?', v:false)
endif
