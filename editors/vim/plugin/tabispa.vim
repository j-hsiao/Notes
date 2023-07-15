"TABIndentSPaceAlignmetn
"Use tab characters for indentation
"Use spaces for alignment
"indentation is always at the beginning of the line.
"effectively:
"tab key = alignment (always spaces)
"i_CTRL-T, i_CTRL-D for indent in insert mode
">>, << for indent in normal mode

function! s:DoTab()
	"Add spaces to next tabstop
	let step = &b:sts
	if step < 0
		let step = &b:sw
	endif
	if step == 0
		let step = &b:ts
	endif
	let index = col('.') - 1
	if curcol > 0
		let upto = curline[:curcol-2]
	else
		let upto = ''
	endif
	let curextra = strdisplaywidth(upto) % step
	return repeat(' ', step - curextra)
endfunction

inoremap <expr> <silent> <Tab> <SID>DoTab()

function! s:DoTab()
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
function! s:DoSTSBS()
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
inoremap <expr> <silent> <C-H> <SID>DoSTSBS()

" shifting, preserve tab/space structure
function! s:SwapIndent(tabfirst)
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

function! s:SwapWrap(keys, before)
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
		let ret = prefix . "call " . expand('<SID>') . "SwapIndent(0)\<CR>"
	endif
	let ret .= a:keys . prefix . "call " . expand('<SID>') . "SwapIndent(1)\<CR>"
	return ret
endfunction
inoremap <expr> <silent> <C-T> <SID>SwapWrap("\<lt>C-T>", 0)
inoremap <expr> <silent> <C-D> <SID>SwapWrap("\<lt>C-D>", 1)
nnoremap <expr> <silent> >> <SID>SwapWrap(">>", 0)
nnoremap <expr> <silent> << <SID>SwapWrap('<lt><lt>', 1)
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

function! s:Realign() range
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

function! s:SetBlockBounds()
	let [firstline, lastline] = s:CalcBlock(line('.'))
	call setpos("'<", [0, firstline, 1, 0])
	call setpos("'>", [0, lastline, 2, 0])
endfunction
nnoremap <silent> <C-K>s :call <SID>SetBlockBounds()<CR>'<lt>V'>
