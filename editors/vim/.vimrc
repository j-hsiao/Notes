"summary of keybindings
"<C-K>  do something
"  ?        ask[?] bindings
"  c        toggle [c]olumn ruler stl
"  n        toggle [n]umbering
"  r        toggle [r]elative numbering
"  l        toggle [l]ist
"  b        scratch [b]uffer
"  )        toggle auto-close mappings (pair ([{ with closing )]})
"  <Tab>    toggle expandtab
"  p        toggle paste

"<C-K><C-K> set an option to numeric value
"  >        [shift]width
"  <Tab>    [tab]stop
"  <S-Tab>  [s]oft [tab]stop

"<S-Tab>    if expandtab: add literal tab
"           else: add spaces
"<C-BS>     when sts == 0, <BS> only deletes 1 char(space)
"           This makes it act as if sts == ts (delete multiple spaces)
"           <S-BS> does not work on home windows, but does on work
"           windows?

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
nnoremap <silent> <C-[><C-[> :nohl<CR>
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
set nowrap number ruler incsearch
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

" autocompletion for [](){} etc
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
			execute 'inoremap ' . oc[0] . ' ' . '<C-o>:call CompleteIfWS("' . oc . '")<CR>'
			execute 'inoremap ' . oc[1] . ' ' . '<C-o>:call IgnoreIfSame("' . oc[1] . '")<CR>'
		endfor
	endif
endfunction

" Column-ruler stl
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

"custom indentation stuffs
function! DoOpTab()
	" insert literal tab char OR spaces up to boundary
	" depending on value of expandtab
	if &l:expandtab
		execute "norm gi\<C-v>\<Tab>"
	else
		" sts=0 avoids merging tabs/spaces allowing adding just
		" spaces
		setlocal et
		let [ots, osts, &l:sts] = [&l:ts, &l:sts, 0]
		if osts > 0
			let &l:ts = osts
		elseif osts < 0 && &l:sw > 0
			let &l:ts = &l:sw
		endif
		execute "norm gi\<Tab>"
		let [&l:ts, &l:sts] = [ots, osts]
		setlocal noet
	endif
endfunction
inoremap <silent> <S-Tab> <C-o>:call DoOpTab()<CR>

function! DoSTSBS()
	" backspace as if sts is on
	" mainly useful if expandtab AND sts==0
	if &l:sts == 0
		let &l:sts = &l:ts
		execute "norm gi\<BS>"
		let &l:sts = 0
	else
		execute "norm gi\<BS>"
	endif
endfunction
inoremap <silent> <C-BS> <C-o>:call DoSTSBS()<CR>

function! GetIndent()
	"Return the indentation on the current line
	"changes '^ mark
	let curline = getline('.')
	execute "norm! I\<Esc>"
	let lasti = getpos("'^")
	let idx = lasti[2] 
	if idx > 1
		return curline[:idx-2]
	else
		return ''
	endif
endfunction

function! CopyIndent(key)
	"autoindent uses the column then most tabs+spaces
	"this just literally copies the indentation
	" much more useful for tab->indent, space->align
	if &l:autoindent
		call feedkeys(a:key, 'n')
		return
	endif
	if a:key == "\<CR>"
		let origpos = getpos("'^")
		let trailing = getline(origpos[1])[origpos[2]-1:]
		execute "norm! gi\<CR>"
		let newpos = getpos("'^")
		" TODO
	else
		"o or O, expect empty line because no autoindent
		"If not empty, then that'd be because of comment.
		"  Either way, always move cursor to the end.
		let indentation = GetIndent()
		let origline = line('.')
		execute 'norm! ' . a:key
		let addedline = line('.')
		if origline == addedline
			let origline = addedline + 1
		endif
		if len(getline(addedline))
			call cursor(origline, 0)
			norm _
			let commentstart = getpos('.')
			norm w
			let wordstart = getpos('.')
			let oline = getline(origline)
			if commentstart[1] == wordstart[1]
				let extra = oline[commentstart[2]-1:wordstart[2]-2]
			else
				let extra = oline[commentstart[2]-1:]
			endif
			call setline(addedline, indentation . extra)
			call cursor(addedline, 0)
		else
			call setline('.', indentation)
		endif
		return feedkeys('A')
	endif
endfunction

function Tst()
	return "gi\<CR>"
endfunction
inoremap <CR> <C-o>:call CopyIndent("\<lt>CR>")<CR>
nnoremap  O :call CopyIndent('O')<CR>
nnoremap  o :call CopyIndent('o')<CR>
