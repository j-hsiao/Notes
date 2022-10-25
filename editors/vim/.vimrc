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

"<-[><-[>   stop highlighting search
"<S-Tab>    literal tab character.
"<Tab>      spaces always
"<C-BS>     delete width of spaces or do 1 bs.
"           (<S-BS> does not register on some cygwins...)
"<C-D>,<C-T>    shift and respect space alignment
"   >>, <<
"<C-K>i     move tabs in (mixed) leading whitespace to beginning
"<C-K>I     move tabs in (mixed) leading whitespace to end
"<C-K><C-K>i    <C-K>i on last selection
"<C-K><C-K>I    <C-K>I on last selection
"<C-K>a     realign block (same or more indent)
"           match previous lower-level indentation and then convert
"           the rest to spaces
"<C-K>s     select block (same or more indent)
"<C-.>      right shift last visual selection
"<C-,>      left shift last visual selection

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
set nowrap number ruler incsearch autoindent copyindent preserveindent
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

" TODO change to <expr> mappings
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
function! <SID>DoTab()
	" Act as if et.  Literal tabs can be added via
	" shifting or shift+tab so a quick-button to
	" add a bunch of spaces up to tabstop for alignment
	" is more useful.
	let step = &l:sts
	if step < 0
		let step = &l:sw
	endif
	if step == 0
		let step = &l:ts
	endif
	" Cannot just use virtcol because if on a tab
	" virtcol will be the last col of the tab, not
	" the first col
	let curline = getline('.')
	let curpos = getpos('.')
	if curpos[2] > 1
		let upto = curline[:curpos[2]-2]
	else
		let upto = ''
	endif
	return repeat(' ', step - strdisplaywidth(upto) % step)
endfunction
" <Tab>: always spaces
" <S-Tab>: raw tab if expandtab else spaces
" tab for indent: use shifting >>,<<,<C-T>,<C-D>
" I could try a <Cmd> map but . repetition does not work with that
inoremap <silent> <S-Tab> <C-V><Tab>
inoremap <expr> <silent> <Tab> <SID>DoTab()

" backspace
function! <SID>DoSTSBS()
	" backspace as if sts is on (for spaces)
	if &l:sts == 0
		let width = &l:ts
	elseif &l:sts < 0
		if &l:sws == 0
			let width = &l:ts
		else
			let width = &l:sws
		endif
	else
		let width = &l:sts
	endif
	let curline = getline('.')
	let curpos = getpos('.')
	if curpos[2] > 1
		let upto = curline[:curpos[2]-2]
	else
		let upto = ''
	endif

	let toremove = strdisplaywidth(upto) % width
	if toremove == 0
		let toremove = width
	endif
	let nspaces = matchstr(upto, '\m \{1,' . toremove . '}$')
	" add a space first to avoid normal sts backspace deletion
	" removing multiple spaces in 1 BS
	return ' ' . repeat("\<BS>", (len(nspaces) ? len(nspaces) : 1)+1)
endfunction
inoremap <expr> <silent> <C-BS> <SID>DoSTSBS()

" shifting, preserve tab/space structure
function! <SID>SwapIndent(tabfirst)
	"Fix indenting caused by preserveindent
	"which adds tabs to after the whitespace
	"rather than before
	let curline = getline('.')
	let parts = matchlist(curline, '^\v(\t*)( *)(\t*)(.*)$')
	if len(parts[2]) > 0
		if len(parts[3]) > 0 && a:tabfirst
			call setline('.', parts[3] . parts[1] . parts[2] . parts[4])
		elseif len(parts[1]) > 0 && ! a:tabfirst
			call setline('.', parts[2] . parts[1] . parts[3] . parts[4])
		endif
	endif
endfunction

function! <SID>SwapWrap(keys, before, prefix)
	let ret = ''
	if v:version > 801
		let prefix="\<Cmd>"
	else
		if a:keys == "<<" || a:keys == ">>"
			let prefix=":"
		else
			let prefix=" \<BS>\<C-O>:"
		endif
	endif
	if  a:before
		let ret = prefix . "call " . a:prefix . "SwapIndent(0)\<CR>"
	endif
	let ret .= a:keys . prefix . "call " . a:prefix . "SwapIndent(1)\<CR>"
	return ret
endfunction
inoremap <expr> <silent> <C-T> <SID>SwapWrap("\<lt>C-T>", 0, '<SID>')
inoremap <expr> <silent> <C-D> <SID>SwapWrap("\<lt>C-D>", 1, '<SID>')
nnoremap <expr> <silent> >> <SID>SwapWrap(">>", 0, '<SID>')
nnoremap <expr> <silent> << <SID>SwapWrap('<lt><lt>', 1, '<SID>')
" '< and '> are not set yet if <Cmd> command
vnoremap <silent> > >:'<lt>,'>call <SID>SwapIndent(1)<CR>'<lt>
vnoremap <silent> <lt> :call <SID>SwapIndent(0)<CR>'<lt>V'><lt>:'<lt>,'>call <SID>SwapIndent(1)<CR>'<lt>

"shift on last visual region
nmap <silent> <C-.> '<lt>V'>>
nmap <silent> <C-,> '<lt>V'><lt>

"raw indent tab/space swapping
nnoremap <silent> <C-K>i :call <SID>SwapIndent(1)<CR>
nnoremap <silent> <C-K>I :call <SID>SwapIndent(0)<CR>
"shortcut for tab/space swap of last selection
nnoremap <silent> <C-K><C-K>i :'<lt>,'>call <SID>SwapIndent(1)<CR>'<lt>
nnoremap <silent> <C-K><C-K>I :'<lt>,'>call <SID>SwapIndent(0)<CR>'<lt>
"tab/space swap in visual mode
vnoremap <silent> <C-K>i :call <SID>SwapIndent(1)<CR>'<lt>
vnoremap <silent> <C-K>I :call <SID>SwapIndent(0)<CR>'<lt>

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
