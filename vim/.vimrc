"summary of keybindings
"<C-K>  do something
"?      ask[?] bindings
"c      toggle [c]olumn ruler stl
"n      toggle [n]umbering
"r      toggle [r]elative numbering
"l      toggle [l]ist
"b      scratch [b]uffer
")      toggle auto-close mappings (pair ([{ with closing )]})
"<Tab>  toggle expandtab
"n      toggle nu
"r      toggle rnu
"p      toggle paste
"
"<C-K><C-K>  set an option to numeric value
">       [shift]width
"<Tab>   [tab]stop
"<S-Tab> [s]oft [tab]stop

syntax on
filetype plugin on
"file ui
set wmnu wim=list:longest,list:full wic
"status line
set ls=2 stl=%<%n\ %f\ %h%m%r%=%l(%p%%),%c%V\ %P
"listchars
set listchars=eol:$,tab:.\ ,trail:.
nnoremap <C-K>l :setlocal list! list?<CR>
"toggle paste
nnoremap <C-K>p :setlocal paste! paste?<CR>
"row numbering
nnoremap <C-K>n :setlocal number! number?<CR>
nnoremap <C-K>r :setlocal relativenumber! relativenumber?<CR>
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
"scratch buffer
nnoremap <C-K>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>
"basic options
nnoremap <C-K>? :nnoremap <lt>C-K><CR>
set nowrap autoindent number ruler
set ignorecase smartcase hlsearch
set hidden belloff=all scrolloff=0 list
set formatoptions+=roj

"Note: one maybe large benefit of ftplugin over autocmd is that
"the ftplugin has its own file-type identification that can be
"updated if vim is updated.  With autocmd, you must update them
"yourself.
" augroup Myft
" 	autocmd! Myft
" 	autocmd Myft bufnewfile,bufread *.py setlocal sts=4 sw=4 expandtab
" 	autocmd Myft bufnewfile,bufread *.c,*.h,*.cpp,*.hpp setlocal sts=2 sw=2 noexpandtab
" 	autocmd Myft bufnewfile,bufread *.cmake,CMakeLists.txt,*.cmake.in setlocal ts=4 sts=0 sw=4
" 	autocmd Myft bufnewfile,bufread *.sh setlocal ts=4 sts=0 sw=4 noexpandtab
" 	autocmd Myft bufnewfile,bufread *.txt setlocal sw=2 sts=4 ts=4
" augroup END

function! IgnoreIfSame(key)
	"handle the case where cursor is on closing key
	"If on a closing key, move 1 over.  Otherwise add the closing key.
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
		call cursor(0,ccol)
		startinsert
	endif
endfunction
function! CompleteIfWS(keypair)
	let curline = getline('.')
	let curbyte = col("'^") - 1
	if curbyte >= len(curline) || curline[curbyte] =~ '\s'
		execute 'norm! a' . a:keypair
	else
		execute 'norm! ' . (curbyte == 0 ? 'i' : 'a') . a:keypair[0]
		call cursor(0, curbyte + 2)
	endif
	startinsert
endfunction
function! ToggleAutoclose()
	"Toggle whether ([{ should be auto-closed.
	"When typing one of these keys, the corresponding
	"close character will be automatically added
	if len(maparg(')', 'i'))
		for oc in split('() [] {}')
			execute 'iunmap ' . oc[0]
			execute 'iunmap ' . oc[1]
		endfor
	else
		for oc in split('() [] {}')
			execute 'inoremap ' . oc[0] . ' ' . '<Esc>:call CompleteIfWS("' . oc . '")<CR>'
			execute 'inoremap ' . oc[1] . ' ' . '<Esc>:call IgnoreIfSame("' . oc[1] . '")<CR>'
		endfor
	endif
endfunction
nnoremap <silent> <C-K>) :call ToggleAutoclose()<CR>
function! RulerSTL(...)
	"Return a string suitable for use as the status line that shows
	"the columns similar to nu.  Numbering starts at 1 and numbers
	"each sts or sw or ts, whichever is non-zero first.  If the max
	"column + indicator + space is larger than the interval, double
	"the interval until the column numbering can fit.
	"Optional arguments: delimiter per column, delimiter for curcol.
	let delim = a:0 ? a:1 : '|'
	let cdelim = a:0 > 1 ? a:2 : '^'
	let step = &sts ? &sts : &sw ? &sw : &ts
	let maxlen = winwidth(0)
	let midlen = len(max([col('$'), maxlen]) . '^ ')
	while step < midlen
		let step += step
	endwhile
	let cwinvpos = wincol()
	let cbufvpos = virtcol('.')
	let curcol = col('.')
	let curchar = getline('.')[curcol-1]
	"For tabs, the virtual column is the last column of the tab
	"rather than the beginning.  However, if list is set, then
	"the cursor is placed on the beginning of the tab rather than
	"the last column of the tab.  Correct the issue.
	if curchar == "\t" && &list
		" could be <space><Tab>
		" to get the tab start, need the end of the previous char
		" can't just take tab and subtract ts-1 because that would
		" give the space's col, not tab's col
		if curcol > 1
			call cursor(0, curcol-1)
			let cbufvpos = virtcol('.') + 1
			call cursor(0, curcol)
		else
			let cbufvpos -= &ts - 1
		endif
	endif
	let maxlen = winwidth(0)
	let mystl = []
	let mystl = repeat([' '], maxlen)
	let lcbegin = cbufvpos - cwinvpos
	let remainder = lcbegin % step
	if remainder < 0
		let remainder += step
	endif

	let idx = -remainder
	let lcbegin -= remainder
	let lcbegin += 1
	if idx < 0
		if lcbegin > 0
			let digits = split(delim . lcbegin, '\zs')
			let shown = len(digits) + idx
			if shown > 0
				let mystl[:idx + len(digits)-1] = digits[-shown:]
			endif
		endif
		let lcbegin += step
		let idx += step
	endif
	for idx in range(idx, maxlen-1, step)
		let digits = split(delim . lcbegin, '\zs')
		let space = min([maxlen - idx, len(digits)])-1
		let mystl[idx:idx+space] = digits[:space]
		let lcbegin += step
	endfor
	let digits = split(cdelim . cbufvpos, '\zs')
	let idx = cwinvpos - 1
	if maxlen - idx < len(digits)
		let [lidx, ridx] = [idx-len(digits), idx+1]
		let mystl[lidx+1:idx-1] = digits[1:]
		let mystl[idx] = cdelim
	else
		let [lidx, ridx] = [idx-1, idx+len(digits)]
		let mystl[idx:ridx-1] = digits
	endif
	while lidx >= 0 && mystl[lidx] != ' '
		let mystl[lidx] = ' '
		let lidx -= 1
	endwhile
	while ridx < maxlen && mystl[ridx] != ' '
		let mystl[ridx] = ' '
		let ridx += 1
	endwhile
	return join(mystl, '')
endfunction

function! CpOrigSTL()
	if ! exists('w:ColRuler_origstl') && &stl == '%!RulerSTL()'
		let w:ColRuler_origstl = getwinvar(winnr('#'), 'ColRuler_origstl')
	endif
endfunction
augroup CpOrigstlOnSplit
 	au! CpOrigstlOnSplit
	au WinEnter * call CpOrigSTL()
augroup END

unlet! w:ColRuler_origstl
function! ColRuler()
	"Toggle using RulerSTL() for stl
	"The original stl line is saved as w:ColRuler_origstl
	if !exists('w:ColRuler_origstl') || &stl != '%!RulerSTL()'
		let w:ColRuler_origstl = &stl
		let &l:stl = '%!RulerSTL()'
	else
		let &l:stl = w:ColRuler_origstl
	endif
endfunction
nnoremap <silent> <C-K>c :call ColRuler()<CR>
