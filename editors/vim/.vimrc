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
nnoremap <silent> <C-K><C-K>> :<C-U>execute "setlocal sw" . (v:count == v:count1 ? "=" . v:count : "&")<CR>
"softtabstop
nnoremap <silent> <C-K><C-K><S-Tab> :<C-U>execute "setlocal sts" . (v:count == v:count1 ? "=" . v:count : "&")<CR>
"tabstop
nnoremap <silent> <C-K><C-K><Tab> :<C-U>execute "setlocal ts" . (v:count == v:count1 ? "=" . v:count : "&")<CR>
"expandtab
nnoremap <silent> <C-K><Tab> :setlocal expandtab! expandtab?<CR>
"scratch buffer
nnoremap <C-K>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>
"basic options
nnoremap <C-K>? :nnoremap <lt>C-K><CR>
set nowrap number ruler incsearch autoindent copyindent
	\ ignorecase smartcase hlsearch
	\ hidden belloff=all scrolloff=0 list
	\ formatoptions+=roj

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
function! s:IgnoreIfSame(key)
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
function! s:CompleteIfWS(keypair)
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
function! <SID>ToggleAutoclose()
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
			execute 'inoremap ' . oc[0] . ' ' . '<C-O>:call s:CompleteIfWS("' . oc . '")<CR>'
			execute 'inoremap ' . oc[1] . ' ' . '<C-O>:call s:IgnoreIfSame("' . oc[1] . '")<CR>'
		endfor
	endif
endfunction

" Column-ruler stl
nnoremap <silent> <C-K>) :call <SID>ToggleAutoclose()<CR>
function! s:RulerSTL(...)
	"Return a string suitable for use as the status line that shows
	"the columns similar to nu.  Numbering starts at 1 and numbers
	"each sts or sw or ts, whichever is non-zero first.  If the max
	"column + indicator + space is larger than the interval, double
	"the interval until the column numbering can fit.
	"Optional arguments: delimiter per column, delimiter for curcol.
	let delim = a:0 ? a:1 : '|'
	let cdelim = a:0 > 1 ? a:2 : '^'
	let step = &l:sts ? &l:sts : &l:sw ? &l:sw : &l:ts
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
	if curchar == "\t" && &l:list
		" could be <space><Tab>
		" to get the tab start, need the end of the previous char
		" can't just take tab and subtract ts-1 because that would
		" give the space's col, not tab's col
		if curcol > 1
			call cursor(0, curcol-1)
			let cbufvpos = virtcol('.') + 1
			call cursor(0, curcol)
		else
			let cbufvpos -= &l:ts - 1
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
	if ! exists('w:ColRuler_origstl') && &l:stl == '%!s:RulerSTL()'
		let w:ColRuler_origstl = getwinvar(winnr('#'), 'ColRuler_origstl')
	endif
endfunction
augroup CpOrigstlOnSplit
	au! CpOrigstlOnSplit
	au WinEnter * call CpOrigSTL()
augroup END

unlet! w:ColRuler_origstl
function! ColRuler()
	"Toggle using s:RulerSTL() for stl
	"The original stl line is saved as w:ColRuler_origstl
	if !exists('w:ColRuler_origstl') || &l:stl != '%!s:RulerSTL()'
		let w:ColRuler_origstl = &l:stl
		let &l:stl = '%!s:RulerSTL()'
	else
		let &l:stl = w:ColRuler_origstl
	endif
endfunction
nnoremap <silent> <C-K>c :call ColRuler()<CR>

"custom indentation handling to work with tabindent + spacealign
" Tab
function! <SID>DoOpTab(expandprefix)
	" insert literal tab char OR spaces up to boundary
	" depending on value of expandtab
	if &l:expandtab
		call feedkeys(a:expandprefix . "\<Tab>", 'n')
	else
		setlocal et
		execute "norm! gi\<Tab>"
		setlocal noet
		call setpos('.', getpos("'^"))
	endif
endfunction
" prevent C-o from killing any autoindents
" If noexpandtab, then <C-D> <C-T> for indentation
" <Tab> for alignment
inoremap <silent> <S-Tab> <Space><BS><C-O>:call <SID>DoOpTab("\<lt>C-v>")<CR>
inoremap <silent> <Tab> <Space><BS><C-O>:call <SID>DoOpTab("")<CR>

" backspace
function! <SID>DoSTSBS()
	" backspace as if sts is on
	" mainly useful if expandtab AND sts==0
	if &l:sts == 0
		let &l:sts = &l:ts
		execute "norm gi\<BS>"
		let &l:sts = 0
		call setpos('.', getpos("'^"))
	else
		call feedkeys("\<BS>", 'n')
	endif
endfunction
" prevent C-o from killing any autoindents
inoremap <silent> <C-BS> <Space><BS><C-O>:call <SID>DoSTSBS()<CR>

" shifting, preserve tab/space structure
function! <SID>DoShift(keys, count)
	" Special handling for shifting if indent/align is detected
	" (\t* \+) also et is off
	if &l:et
		call feedkeys(a:keys, 'n')
		return
	endif
	let curline = getline('.')
	if a:keys == "\<C-T>" || a:keys == "\<C-D>"
		let curpos = getpos("'^")
	else
		let curpos = getpos('.')
		if len(curline) == 0
			" in normal mode, do not shift blank lines
			return
		endif
	endif
	let data = matchlist(curline, '^\v(\t*)( *)(.*)')
	if a:count > 0
		call setline('.', repeat("\<Tab>", a:count) . data[0])
		call cursor(curpos[1], curpos[2] + a:count)
	elseif a:count < 0
		let tabs = data[1][-a:count:]
		if len(tabs)
			call setline('.', tabs . data[2] . data[3])
			call cursor(curpos[1], curpos[2] + a:count)
		else
			let removed = len(data[1])
			let toremove = a:count + len(data[1])
			let shift = &l:sw ? &l:sw : &l:ts
			let amount = 0
			let amount = min([len(data[2]) / shift, toremove])
			call setline('.', data[2][amount*shift:] . data[3])
			call cursor(curpos[1], curpos[2] - (removed + shift * amount))
		endif
	endif
endfunction
inoremap <silent> <C-T> <Space><BS><C-O>:call <SID>DoShift("\<lt>C-t>", 1)<CR>
nnoremap <silent> >> :<C-U>call <SID>DoShift('>>', v:count1)<CR>
inoremap <silent> <C-D> <Space><BS><C-O>:call <SID>DoShift("\<lt>C-d>", -1)<CR>
nnoremap <silent> <lt><lt> :<C-U>call <SID>DoShift('<lt><lt>', -v:count1)<CR>
function! s:CalcBlock(lnum)
	" Return start and stop line of block
	" A block is a series of lines indented at least
	" to the same display column as current line.
	let bstart = a:lnum
	let bstop = bstart
	let curline = getline(bstart)
	if len(curline) == 0
		let above = prevnonblank(a:lnum)
		let aboveindent = len(matchstr(getline(above), '^\m[[:space:]]*'))
		let below = nextnonblank(a:lnum)
		let belowindent = len(matchstr(getline(below), '^\m[[:space:]]*'))
		if aboveindent > belowindent
			return s:CalcBlock(above)
		elseif aboveindent < belowindent || aboveindent > 0
			return s:CalcBlock(below)
		else
			return [0, 0]
		endif
	endif
	let indent = matchstr(curline, '\m[[:space:]]*')
	let icol = strdisplaywidth(indent)
	let check = getline(bstart - 1)
	while bstart > 1 && (
		\ strdisplaywidth(matchstr(check, '\m[[:space:]]*')) >= icol
		\ || len(check) == 0)
		let bstart -= 1
		let check = getline(bstart - 1)
	endwhile
	let check = getline(bstop + 1)
	let lastline = line('$')
	while bstop < lastline && (
		\ strdisplaywidth(matchstr(check, '\m[[:space:]]*')) >= icol
		\ || len(check) == 0)
		let bstop += 1
		let check = getline(bstop + 1)
	endwhile
	return [bstart, bstop]
endfunction

function! <SID>Realign() range
	" Realign a block of lines.
	" (Tabs followed by spaces)
	if &l:et
		return
	endif
	let [bstart, bstop] = s:CalcBlock(line('.'))
	if bstart == 0
		return
	endif
	let parlnum = bstart == 1 ? 1 : bstart - 1
	let parline = getline(parlnum)
	while len(parline) == 0 && parlnum < bstop
		let parlnum += 1
		let parline = getline(parlnum)
	endwhile
	if len(parline) == 0
		return
	endif
	if match(parline, '^\v\t* *([^[:space:]]|$)') >= 0
		let indentation = matchstr(parline, '^\m\t*')
	else
		let icol = strdisplaywidth(matchstr(parline, '\m[[:space:]]*'))
		let indentation = repeat("\<Tab>", icol / &l:ts)
	endif
	let tabend = strdisplaywidth(indentation)
	for lineno in range(bstart, bstop)
		let curline = getline(lineno)
		if len(curline) > 0
			let data = matchlist(curline, '^\v([[:space:]]*)(.*)')
			let icol = strdisplaywidth(data[1])
			call setline(lineno, indentation . repeat(' ', icol - tabend) . data[2])
		endif
	endfor
endfunction
nnoremap <silent> <C-K>a :call <SID>Realign()<CR>

function! <SID>SetBlockBounds()
	let [firstline, lastline] = s:CalcBlock(line('.'))
	call setpos("'<", [0, firstline, 1, 0])
	call setpos("'>", [0, lastline, 2, 0])
endfunction
nnoremap <silent> <C-K>s :call <SID>SetBlockBounds()<CR>'<lt>V'>
