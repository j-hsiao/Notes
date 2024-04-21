"tabispa: TABIndentSPaceAlignment
"
"Indentation is whitespace at the very beginning of the line.  Alignment
"generally refers to any whitespace after indentation but before the
"first non-whitespace character if any.
"A line thus generally has 3 segments: |indentation|alignment|text|
"Extra alignment may exist inside the text segment.
"
"------------------------------
"Relevant options:
"------------------------------
"Regarding tabs/spaces/indentation, there are 3 settings
"1. 'tabstop'
"2. 'softtabstop'
"3. 'shiftwidth'
"
"There is also a setting that controls whether tabs are used:
"'expandtab'
"
"Under tabispa rules, there are 2 types of whitespace: indentation and
"alignment which may be different sizes:
"               expandtab       noexpandtab
"indentation    shiftwidth      tabstop
"alignment      softtabstop     softtabstop
"
"In general, 'shiftwidth' is the actual indentation amount.  However,
"if <Tab> is used to represent indent, then the indentation amount must
"be 'tabstop'.  Usually shiftwidth is effectively the same as tabstop
"anyways.
"
"------------------------------
"Adding Indentation/Alignment.
"------------------------------
"Alignment at current cursor position:
"<Tab>: add alignment
"<C-H>: remove alignment.
"
"Alignment/indentation at start of line:
"                   add align   rm alignment    indent  unindent
"   normal mode:    <C-K><C-L>  <C-K><C-J>      >>      <<
"   visual mode:    <C-K><C-L>  <C-K><C-J>      >       <
"   insert mode:    <C-K><C-L>  <C-K><C-J>      <C-D>   <C-T>

"Observations:
"	Insert mode <C-T>, <C-D> do NOT preserve the alignment level of the
"	first non-indent character.
"	Normal mode << and >> DO preserve the alignemnt level of the first
"	non-indent character.
"	eg.
"	              line start
"	              |
"	start with    |  something
"	after i_<C-T> |  [tabchar]something
"	  again       |  [tabchar][tabchar  ]something
"	after n_>>    |  [tabchar]  something
"	  again       |  [tabchar]  [tabchar]  something
"

if get(g:, 'loaded_tabispa', 0)
	finish
endif
let g:loaded_tabispa = 1

se preserveindent
" calculate the soft tabstop width
" 0 -> off
" <0 -> use shiftwidth
"
" shiftwidth
" 0 -> ts
" < 0 -> sw
"   sw == 0 -> ts
function! s:STS()
	if &l:sts < 0
		return shiftwidth()
	elseif &l:sts == 0
		return &l:ts
	else
		return &l:sts
	endif
endfunction

"Insert spaces at current cursor position until next
"soft tabstop column
function! s:InsertAlignmentAction()
	"Add spaces to next soft tabstop for alignment
	let curpos = strdisplaywidth(strpart(getline('.'), 0, col('.')-1))
	let step = s:STS()
	return repeat(' ', step-(curpos%step))
endfunction
inoremap <expr> <Plug>TabispaInsertAlignmentAction; <SID>InsertAlignmentAction()
function! s:InsertAlignmentDispatch()
	if &l:et
		return "\<Plug>TabispaInsertAlignmentFallback;"
	else
		return "\<Plug>TabispaInsertAlignmentAction;"
	endif
endfunction
execute jhsiaomapfallback#CreateFallback(
	\ '<Plug>TabispaInsertAlignmentFallback;', '<Tab>', 'i')
imap <expr> <Plug>TabispaInsertAlignment; <SID>InsertAlignmentDispatch()
if !hasmapto('<Plug>TabispaInsertAlignment;')
	imap <Tab> <Plug>TabispaInsertAlignment;
endif

"Easier to add multiple literal tabs
if maparg('<S-Tab>', 'i') == ''
	inoremap <S-Tab> <C-V><Tab>
endif

"Remove spaces until softtabstop col to the left
function! s:BackspaceAlignmentAction()
	"Remove multiple spaces until next tabstop or fallback to <BS>
	let prestr = strpart(getline('.'), 0, col('.')-1)
	let curpos = strdisplaywidth(prestr)
	let step = s:STS()
	let to_remove = curpos % step
	if to_remove == 0
		let to_remove = step
	endif
	let nspaces = strlen(matchstr(prestr, printf('\m \{1,%d\}$', to_remove)))
	"space+BS to ensure removing single chars even if after shifting
	return ' ' . repeat("\<BS>", nspaces+1)
endfunction
inoremap <expr> <Plug>TabispaBackspaceAlignmentAction; <SID>BackspaceAlignmentAction()

function! s:BackspaceAlignmentDispatch(key)
	if strpart(getline('.'), col('.')-2, 1) == ' '
		return "\<Plug>TabispaBackspaceAlignmentAction;"
	else
		return printf("\<Plug>TabispaBackspaceAlignmentFallback%s;", a:key)
	endif
endfunction

execute jhsiaomapfallback#CreateFallback(
	\ '<Plug>TabispaBackspaceAlignmentFallbackCH;', '<C-H>', 'i')
imap <expr> <C-H> <SID>BackspaceAlignmentDispatch('CH')

"Add alignment.  Return Add position and result.
function! s:RawAddAlignment(line, sts)
	let parts = matchlist(a:line, '\m^\(\s*\)\(.*\)$')
	return [
		\ strlen(parts[1]),
		\ join([parts[1], repeat(' ', a:sts), parts[2]], '')]
endfunction

"Remove alignment.  Return remove position and result.
function! s:RawRemoveAlignment(line, sts)
	let parts = matchlist(a:line, '\m^\(\t*\)\( *\)\(.*\)$')
	return [
		\ strlen(parts[1]),
		join([parts[1], strpart(parts[2], a:sts), parts[3]], '')]
endfunction


"insert mode:
"	base: add indent after comment character
"	alt: always add at beginning of line
"normal mode:
"	base: always add at beginning of line
"	alt: add indent after comment character
"visual mode:
"	base: always add at beginning of line
"	alt: add indent after comment character only if all selected lines
"		are commented.
function! s:AddIndent(raw) range
	if &l:et
		if &l:sw == 0
			let prefix = repeat(' ', &l:ts)
		else
			let prefix = repeat(' ', &l:sw)
		endif
	else
		let prefix = "\<Tab>"
	endif
	let [singles, multis] = jhsiaoutl#ParseComments()
	let raw = a:raw
	if !a:raw && a:firstline != a:lastline
		let curline = a:firstline
		while curline <= a:lastline
			let text = getline('.')
			jhsiaoutil#MatchComment(text, singles, multis, 2, 3)

			if curline == a:firstline && 
		endwhile
	endif

	if a:firstline == a:lastline
		if a:0
		else
		endif
	else
		if !a:base
			let curline = a:firstline
			let iscomment = v:false
			while iscomment && curline <= a:lastline
				let text = getline(curline)
				for single in singles
					let parts = matchlist(text, single['reg'])
					if len(parts)
						let iscomment = v:true
						break
					endif
				endfor
				if !iscomment
					for multi in multis
						let parts = matchlist(text, multi['reg'])
						if strlen(parts[2])
							let ncurline = curline
							while ncurline <= a:lastline
								let ntext = getline(curline)
								let parts = matchlist(ntext, multi['reg'])
								if strlen(parts[5])
									break
								endif
								let ncurline += 1
							endwhile
							let iscomment = v:true
							break
						endif
					endfor
				endif
				let curline += 1
			endwhile
			if iscomment
				return
			endif
		endif
		let curline = a:firstline
		while curline != a:lastline
			call setline(curline, prefix . getline(curline))
			let curline += 1
		endwhile
	endif
endfunction

function! s:ParseLineRanges(lst)
	if len(a:lst)
		if type(a:lst[0]) == v:t_number
			let num = a:lst[0]
		else
			let num = line(a:lst[0])
		endif
		return [num, num]
	else
		let curno = line('v')
		let lastline = line('.')
		if lastline < curno
			return [lastline, curno]
		else
			return [curno, lastline]
		endif
	endif
endfunction

function! s:AddIndent(...)
	let [curno, lastline] = s:ParseLineRanges(a:000)
	if &l:et
		let pre = repeat(' ', shiftwidth())
	else
		let pre = "\<Tab>"
	endif
	let pattern = jhsiaoutil#GetCMSPattern()
	"TODO: If all lines are comments, then use post-comment indentation
	"otherwise if some comments and some not, it's probably desired to
	"indent everything as normal...
	while curno <= lastline
		let curline = getline(curno)
		let parts = matchlist(curline, pattern)
		if strlen(parts[2])
			let parts[0] = join(['%s%s', '%s%s%s'], pre)
			call setline(curno, call('printf', parts[:5]))
			if a:0
				call jhsiaoutil#CursorShift(
					\ strlen(join(parts[1:2], '')), strlen(pre))
			endif
		else
			call setline(curno, join([pre, curline], ''))
			if a:0
				call jhsiaoutil#CursorShift(0, strlen(pre))
			endif
		endif
		let curno += 1
	endwhile
	return ''
endfunction
inoremap <Plug>TabispaAddIndent; <C-R>=<SID>AddIndent('.')<CR>
inoremap <Plug>TabispaAddIndentOld; <C-T>
nnoremap <Plug>TabispaAddIndent; :call <SID>AddIndent('.')<CR>
nnoremap <Plug>TabispaAddIndentOld; >>
vnoremap <Plug>TabispaAddIndent; :call <SID>AddIndent()<CR>'>
vnoremap <Plug>TabispaAddIndentOld; >
imap <C-T> <Plug>TabispaAddIndent;
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'imap <C-K><C-T> <Plug>TabispaAddIndentOld;', '<C-T>')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'nmap >> <Plug>TabispaAddIndent;', '.')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'nmap <C-K>> <Plug>TabispaAddIndentOld;', '.')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'vmap > <Plug>TabispaAddIndent;', '.', 'n')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'vmap <C-K>> <Plug>TabispaAddIndentOld;', '.', 'n')

function! s:RemoveIndent(...)
	let [curno, lastline] = s:ParseLineRanges(a:000)
	let spacepat = printf('\m^\( \{1,%s\}\)\(.*\)', shiftwidth())
	if &l:et
		let pre = ' '
		let prepat = spacepat
	else
		let pre = "\<Tab>"
		let prepat = '\m^\(\t\)\(.*\)'
	endif
	let pattern = jhsiaoutil#GetCMSPattern()
	"TODO: If all lines are comments, then use post-comment unindent.
	"otherwise if some comments and some not, it's probably desired to
	"unindent everything as normal...
	while curno <= lastline
		let curline = getline(curno)
		let parts = matchlist(curline, pattern)
		if strlen(parts[2])
			let iparts = matchlist(parts[3], prepat)
			if !len(iparts) && pre != ' '
				let iparts = matchlist(parts[3], spacepat)
			endif
			if len(iparts)
				let offset = strlen(join(parts[1:2], ''))
				call jhsiaoutil#CursorShift(offset, -strlen(iparts[1]))
				call setline(
					\ curno,
					\ strpart(curline, 0, offset)
					\ . strpart(curline, offset + strlen(iparts[1])))
			endif
		else
			let parts = matchlist(curline, prepat)
			if !len(parts) && pre != ' '
				let parts = matchlist(curline, spacepat)
			endif
			if len(parts)
				call jhsiaoutil#CursorShift(0, -strlen(parts[1]))
				call setline(curno, parts[2])
			endif
		endif
		let curno += 1
	endwhile
	return ''
endfunction
inoremap <Plug>TabispaRemoveIndent; <C-R>=<SID>RemoveIndent('.')<CR>
inoremap <Plug>TabispaRemoveIndentOld; <C-D>
nnoremap <Plug>TabispaRemoveIndent; :call <SID>RemoveIndent('.')<CR>
nnoremap <Plug>TabispaRemoveIndentOld; <lt><lt>
vnoremap <Plug>TabispaRemoveIndent; :call <SID>RemoveIndent()<CR>'<lt>
vnoremap <Plug>TabispaRemoveIndentOld; <lt>
imap <C-D> <Plug>TabispaRemoveIndent;
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'imap <C-K><C-D> <Plug>TabispaRemoveIndentOld;', '<C-D>')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'nmap <lt><lt> <Plug>TabispaRemoveIndent;', '.')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'nmap <C-K><lt> <Plug>TabispaRemoveIndentOld;', '.')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'vmap <lt> <Plug>TabispaRemoveIndent;', '.', 'n')
execute jhsiaocrepeat#CharRepeatedCmds(
	\ 'vmap <C-K><lt> <Plug>TabispaRemoveIndentOld;', '.', 'n')

"TODO: alignment


function! s:Realign()
	"Rearrange all leading spaces/tabs to be tabs first then spaces
	"NOTE: this may change the number of spaces depending on the
	"placement of the tabs.  The  number of tabs will remain the same
	"though.
	let ntabs = 0
	let nspace = 0
	let curline = getline('.')
	let unaligned = 0
	for char in curline
		if char == ' '
			let nspace += 1
		elseif char == "\<Tab>"
			let ntabs += 1
			let unaligned = nspace
		else
			break
		endif
	endfor
	if unaligned
		let width = strdisplaywidth(strpart(curline, 0, ntabs + nspace))
		let padspace = width - (&l:ts * ntabs)
		let parts = [
			\ repeat("\<Tab>", ntabs),
			\ repeat(' ', padspace),
			\ strpart(curline, ntabs+nspace)]
		if padspace < nspace
			let curbyte = col('.') - 1
			if curbyte >= ntabs + nspace
				"After whitespace should always be in same visual position.
				call jhsiaoutil#CursorShift(0, padspace - nspace)
			else
				"Keep cursor in similar visual position.
				"guaranteed to be simple byte chars (tab or space)
				"no multi-byte chars to complicate byte indexing.
				let viscol = strdisplaywidth(strpart(curline, 0, curbyte))
				let curpos = getpos('.')
				let tabwidth = &l:ts * ntabs
				if viscol >= tabwidth
					let curpos[2] = curbyte / &l:ts
				else
					let curpos[2] = ntabs + (viscol - tabwidth)
				endif
				call setpos('.', curpos)
			endif
		endif
		call setline('.', join(parts, ''))
	endif
endfunction

"function! s:SelectBlock()
"	"If no indentation, then break at blank lines (lines with only
"	"space/tab) otherwise include them.
"	let lineno = line('.')
"	let ind = matchstr(getline('.'), '^\m[\t ]*')
"	let firstline = lineno - 1
"	let lastline = lineno + 1
"	while firstline > 0
"		let check = getline(firstline)
"		let sameindent = !len(ind) || check[:len(ind)-1] == ind
"		let blank = match(check, '\m[ \t]*$') == 0
"		if (len(ind) && (sameindent || blank)) || (!len(ind) && !blank)
"			let firstline -= 1
"		else
"			break
"		endif
"	endwhile
"	let nlines = line('$')
"	let wtf = ''
"	while lastline <= nlines
"		let check = getline(lastline)
"		let sameindent = !len(ind) || check[:len(ind)-1] == ind
"		let blank = match(check, '\m[ \t]*$') == 0
"		let wtf .= lastline . ',' . blank . ','
"		if (len(ind) && (sameindent || blank)) || (!len(ind) && !blank)
"			let lastline += 1
"		else
"			break
"		endif
"	endwhile
""	echo len(ind) . ',' . firstline . ',' . lastline . '|' . wtf
""	return ""
"	return (firstline+1) . 'GV' . (lastline-1) . 'G'
"endfunction
"
"nnoremap <expr> <C-K>s <SID>SelectBlock()
"
"
"" Convert space/tabs up to col into all tabs
"" any remaining whitespace is converted to spaces.
"" col and ws should be virtual columns (0-based)
"function! s:TabToCol(line, col, ws, txt)
"	let tabend = a:col / &l:ts
"	let tabs = repeat("\t", tabend)
"	let align = repeat(' ', a:ws - a:col)
"	let txtidx = 0
"	for char in a:txt
"		if char != ' ' && char != "\t"
"			break
"		endif
"		let txtidx += 1
"	endfor
"	let txt = a:txt[txtidx:]
"	if strcharpart(a:txt, 0, tabend) != tabs || strcharpart(a:txt, tabend, a:ws-a:col) != align
"		call setline(a:line, tabs . align . txt)
"	endif
"endfunction
"
""Smart retabbing, generally space->tabs
""Assumptions:
""       1. indentation is always by tabspace (check value of &l:ts)
""       2. Any increase in indent() not equal to &l:ts is alignment
""       3. Decrease indentation that is a multiple of &l:ts is indentation
"function! s:Tabify() range
"	let curline = a:firstline
"	let ws = indent(curline)
"	let previndent = ws - ws % &l:ts
"	call s:TabToCol(curline, previndent, ws, getline(curline))
"	let curline += 1
"	while curline <= a:lastline
"		let txt = getline(curline)
"		let ws = indent(curline)
"		if ws == strdisplaywidth(txt)
"			if ws
"				call setline(curline, "")
"			endif
"		elseif ws == previndent
"			call s:TabToCol(curline, previndent, ws, txt)
"		elseif ws > previndent && ws == previndent + &l:ts || ws < previndent && ws % &l:ts == 0
"			call s:TabToCol(curline, ws, ws, txt)
"			let previndent = ws
"		else
"			if previndent < ws
"				call s:TabToCol(curline, previndent, ws, txt)
"			else
"				echo "Bad line " . curline . ". Unindented to a non-tabstop (" . ws . ' spaces, ts=' . &l:ts . ')'
"				return
"			endif
"		endif
"		let curline += 1
"	endwhile
"endfunction
"
"nnoremap <silent> <C-K><C-K><C-K><Tab> :<C-U>call <SID>Tabify()<CR>
"vnoremap <C-K><Tab> :call <SID>Tabify()<CR>
"
""Fixed indent to a level (number of tabs)
""Mostly useful if Tabify() can't distinguish between indent and align
""because alignment is also a multiple of &l:ts
"function! s:FixedIndent(indent) range
"	let curline = a:firstline
"	let icol = a:indent * &l:ts
"	while curline <= a:lastline
"		let ws = indent(curline)
"		let txt = getline(curline)
"		if ws == strdisplaywidth(txt)
"			if ws
"				call setline(curline, '')
"			endif
"		else
"			if ws < icol
"				let ws = icol
"			endif
"			call s:TabToCol(curline, icol, ws, txt)
"		endif
"		let curline += 1
"	endwhile
"endfunction
"nnoremap <silent> <C-K><Bslash> :<C-U>call <SID>FixedIndent(v:count)<CR>
"vnoremap <C-K><Bslash> :call <SID>FixedIndent(v:count)<CR>
"
