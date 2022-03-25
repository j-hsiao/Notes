syntax on
filetype plugin on
"file ui
set wmnu wim=list:longest,list:full wic
"status line
set ls=2 stl=%<%n\ %f\ %h%m%r%=%l(%p%%),%c%V\ %P
"listchars
set listchars=eol:$,tab:.\ ,trail:.
nnoremap <C-K><C-L> :setlocal list! list?<CR>
"cancel search highlights
nnoremap <silent> <Esc><Esc> :nohl<CR>
"shiftwidth
nnoremap <silent> <C-K><C-K>> :<C-U>execute "setlocal sw" . (v:count == 0 ? "&" : "=" . v:count)<CR>
"softtabstop
nnoremap <silent> <C-K><C-K><S-Tab> :<C-U>execute "setlocal sts" . (v:count == 0 ? "&" : "=" . v:count)<CR>
"tabstop
nnoremap <silent> <C-K><C-K><Tab> :<C-U>execute "setlocal ts" . (v:count == 0 ? "&" : "=" . v:count)<CR>
"expandtab
nnoremap <silent> <C-K><Tab> :setlocal expandtab! expandtab?<CR>
"relativenumber
nnoremap <silent> <C-K>r :setlocal relativenumber! relativenumber?<CR>
"scratch buffer
nnoremap <C-K>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>
"basic options
set nowrap autoindent number ruler
set ignorecase smartcase hlsearch
set hidden belloff=all scrolloff=0 list
set formatoptions+=roj

augroup Myft
	autocmd! Myft
	autocmd Myft bufnewfile,bufread *.py setlocal sts=4 sw=4 expandtab
	autocmd Myft bufnewfile,bufread *.c,*.h,*.cpp,*.hpp setlocal sts=2 sw=2 noexpandtab
	autocmd Myft bufnewfile,bufread *.cmake,CMakeLists.txt setlocal ts=4 sts=0 sw=4
	autocmd Myft bufnewfile,bufread *.sh setlocal ts=4 sts=0 sw=4 noexpandtab
	autocmd Myft bufnewfile,bufread *.txt setlocal sw=2 sts=4 ts=4
augroup END

"auto-add and close ([{
function! IgnoreIfSame(key)
	let [curline, ccol] = [getline("."), col("'^")]
	let llen = len(curline)
	if ccol > llen || curline[ccol-1] != a:key
		execute 'norm! gi' . a:key . "\<Esc>"
		let llen += 1
	endif
	let ccol += 1
	if ccol > llen
		startinsert!
	else
		call cursor(line('.'),ccol)
		startinsert
	endif
endfunction
function! ToggleAutoclose()
	if len(maparg(')', 'i'))
		echo 'found!'
		for oc in split('() [] {}')
			execute 'iunmap ' . oc[0]
			execute 'iunmap ' . oc[1]
		endfor
	else
		for oc in split('() [] {}')
			execute 'inoremap ' . oc[0] . ' ' . oc . '<Esc>i'
			execute 'inoremap ' . oc[1] . ' ' . '<Esc>:call IgnoreIfSame("' . oc[1] . '")<CR>'
		endfor
	endif
endfunction
nnoremap <silent> <C-K>) :call ToggleAutoclose()<CR>
function! ColRuler()
	let step = &sts
	if step == 0
		let step = &ts
	endif
	let step = max([step, len(col('$') . '')+2])
	let cursorcolw = wincol()
	let colb = col('.')
	let totalwidth = winwidth(0)
	let leftsize = cursorcolw - 1

	let leftstr = repeat(' ', leftsize)

	let midsize = len(colb . '') + 1

	let rightsize = totalwidth - (cursorcolw + midsize - 1)

	let leftstr = repeat('L', leftsize)
	let rightcol = (colb - (colb % step)) + step + 1
	let rightfmt = rightcol - colb - 1
	let rightnums = []
	while rightfmt + (len(rightnums)+1) * step <= rightsize
		call add(rightnums, rightcol)
		let rightcol += step
	endwhile
	if len(rightnums)
		let rightfmt = repeat(' ', rightfmt) . repeat('|%-' . step . 'd', len(rightnums))
		let rightstr = call('printf', [rightfmt] + rightnums)
	else
		let rightstr = ''
	endif

	return leftstr . '|' . colb . rightstr
endfunction

function! EchoRuler()
	"a number every N columns
	"use statusline because no way to figure out viewport's window column
	if &stl != '%<%n %f %h%m%r%=%l(%p%%),%c%V %P'
		let &l:stl = '%<%n %f %h%m%r%=%l(%p%%),%c%V %P'
	else
		let &l:stl = '%!ColRuler()'
	endif
endfunction
nnoremap <C-K>r :call EchoRuler()<CR>
