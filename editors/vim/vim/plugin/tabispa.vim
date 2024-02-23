"tabispa: TABIndentSPaceAlignment
"When expandtab, just default to normal behavior.
"Otherwise:
"   Use tabs for indentation.  Use spaces for alignment.
"   alignment is always after indentation.
"                   add align   rm alignment    indent  unindent
"   normal mode:    <C-K><C-L>  <C-K><C-J>      >>      <<
"   visual mode:    <C-K><C-L>  <C-K><C-J>      >       <
"   insert mode:    <C-K><C-L>  <C-K><C-J>      <C-D>   <C-T>
"
"The number of spaces for alignment is determined by softtabstop.
"
"
"
"In the case of comments, indentation/alignment are handled separately before
"and after the comment char
"
"Used options:
"	'ts' indicates indentation
"	'sts' indicates alignment
"	'sw' should be same as 'ts'
"Usage:
"	normal mode:
"	  <C-K>a: realign current line (move tabs to beginning, maintain
"	    indent/alignment level)
"	  <C-K>A: Same as above, but apply to range '<,'>
"	  <C-K>s: Select block with same indentation (exclude empty lines)
"	insert mode:
"	  <C-T>, <C-D>: Add/remove tabs at 0 position (if not et, else ts spaces)
"	  <C-H>: delete like sts
"	  <Tab>: add sts spaces
"	  <S-Tab>: literal tab
"
"Observations:
"	Insert mode <C-T>, <C-D> do NOT preserve the alignment level of the
"	first non-indent character.
"	Normal mode << and >> DO preserve the alignemnt level of the first
"	non-indent character.
"	eg.
"	start with    |  something
"	after i_<C-T> |  [tabchar]something
"	  again       |  [tabchar][tabchar  ]something
"	after n_>>    |  [tabchar]  something
"	  again       |  [tabchar]  [tabchar]  something
"
"  . does not repeat an entire mapping so just add realignment hotkeys.

"TODO indent->add tab to beginning
"     align->add spaces before first non-white-space
"     corresponding opposites

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
	let step = &l:sts
	if &l:sts < 0
		if &l:sw == 0
			return &l:ts
		endif
		return &l:sw
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
	let nspaces = strlen(matchstr(prestr, '\m \{1,' . to_remove . '\}$'))
	"space+BS to ensure removing single chars even if after shifting
	return ' ' . repeat("\<BS>", nspaces+1)
endfunction
inoremap <expr> <Plug>TabispaBackspaceAlignmentAction; <SID>BackspaceAlignmentAction()

function! s:BackspaceAlignmentDispatch(key)
	if strpart(getline('.'), col('.')-2, 1) == ' '
		return "\<Plug>TabispaBackspaceAlignmentAction;"
	else
		return "\<Plug>TabispaBackspaceAlignmentFallback" . a:key . ';'
	endif
endfunction

execute jhsiaomapfallback#CreateFallback(
	\ '<Plug>TabispaBackspaceAlignmentFallbackCH;', '<C-H>', 'i')
imap <expr> <C-H> <SID>BackspaceAlignmentDispatch('CH')


"Add indentation to a given text line.
function! s:RawAddIndent(line)
	return "\<Tab>" . a:line
endfunction

"Remove indentation from a given text line.
function! s:RawRemoveIndent(line)
	return substitute(a:line, '\m^\t', '', '')
endfunction

"Add alignment.  Return Add position and result.
function! s:RawAddAlignment(line)
	let parts = matchlist(a:line, '\m^\(\s*\)\(.*\)$')
	let sts = s:STS()
	return [strlen(parts[1]), parts[1] . repeat(' ', sts) . parts[2]]
endfunction

function! s:AddIndent(line)
endfunction
function! s:RemoveIndent(line)
endfunction
function! s:AddAlignment(line)
endfunction
function! s:RemoveAlignment(line)
endfunction

"               indentation     alignment
"insert mode:   <C-T><C-D>      <C-K>-><C-L>/<C-J>
"normal mode:   >> <<           <C-K>-><C-L>/<C-J>
"visual mode:   > <             <C-K>-><C-L>/<C-J>
"     original = >, <, but after doing this, visual mode is exited
"     . will only redo the last change (insert mode)
"     range function call will not be repeated by .
"     block insert and delete are . redoable, works for addindent
"     but what if different indent levels? how to handle alignment?
"     works for add indent
"Return information about the current line.
"indentation/alignment insertion points.
"For comments, indentation/alignment is added after the comment chars
"any trailing whitespace in the 'commentstring' will be preserved.
"normal line:
"indent insertion point
"|                       |alignment insertion point
"<Tab><Tab><Space><Space>text
"comment line:
"                                     indent insertion point
"                                     |                       |alignment insertion point
"<Tab><Tab><Space><Space><comentchars><Tab><Tab><Space><Space>text
"
"eg. commentstring = '// %s'
"
"                           indent insertion point
"                           |                       |alignment insertion point
"<Tab><Tab><Space><Space>// <Tab><Tab><Space><Space>text
function! s:IndentInfo(line)
	let cmprefix = split(&l:cms, '%s')[0]
	let cmprechar = matchstr(cmprefix, '\m\S\+')
	if a:line =~ '\m\s*' . cmprechar
		if cmprefix != cmprechar && a:line =~ '\m\s*' . cmprefix
		else
		endif


		"'\m' . cmprechar . '\s*'

		"a:line =~ 

		let indentation = matchstr(a:line, '\m^\s*')
	else
		let indentation = matchstr(a:line, '\m^\s*')
		let indent = 0
		let align = strlen(indentation)
	endif
	return ''
endfunction
nnoremap <expr> <C-K><C-L> <SID>IndentInfo(getline('.'))

"Insert a tab at the beginning
"function! s:AddIndent(mode) range
	"if a:mode == 'v'
		"let curline = a:firstline
		"while curline <= a:lastline
			"call setline(curline, "\<Tab>" . getline(curline))
			"let curline += 1
		"endwhile
	"else
		"if a:mode == 'i'
			"if 1 || "\<Cmd>" == '<Cmd>'
				"return "\<C-O>0\<C-V>\<Tab>" . repeat("\<Right>", col('.')-1)
			"else
				"return "\<Cmd>" . 'call setline(".", "\<Tab>" . getline("."))' . "\<CR>\<Right>"
			"endif
		"elseif a:mode == 'n'
			"return "0i\<C-V>\<Tab>\<Esc>"
		"else
			"return ""
		"endif
	"endif
"endfunction

"inoremap <expr> <Plug>TabispaAddIndentAction; <SID>AddIndent('i')
"nnoremap <expr> <Plug>TabispaAddIndentAction; <SID>AddIndent('n')

"nnoremap <Plug>TabispaAddIndentActionv; :'<lt>'>call <SID>AddIndent('v')<CR>
"vnoremap <Plug>TabispaAddIndentAction; :call <SID>AddIndent('v')<CR>

"inoremap <expr> <C-T> <SID>AddIndent('i')
"nnoremap <expr> >> <SID>AddIndent('n')

"nmap <C-K><C-L> 
"vmap <C-K><C-L> :call <SID>AddIndent('v')<CR>
		"whatever
		"whatever
		"whatever
		"whatever
		"whatever
		"whatever

function! s:Realign()
	"Rearrange all leading spaces/tabs to be tabs first then spaces
	"NOTE: this may change the number of spaces depending on the
	"placement of the tabs.  The  number of tabs will remain the same
	"though.
	let ntabs = 0
	let nspace = 0
	let curline = getline('.')
	let check = ''
	let unaligned = 0
	for char in curline
		if char == ' '
			let nspace += 1
			let check .= 's'
		elseif char == "\t"
			let ntabs += 1
			let check .= 't'
			let unaligned = nspace
		else
			break
		endif
	endfor
	if unaligned
		let width = strdisplaywidth(slice(curline, 0, ntabs + nspace))
		let curpos = col('.')
		let padspace = width - (&l:ts * ntabs)
		call setline('.', repeat("\t", ntabs) . repeat(' ', padspace) . curline[ntabs+nspace:])
		call cursor(0, curpos + padspace - nspace)
	endif
endfunction
"
"function! s:AddIndent()
"	"Insert a tab character at beginning of line
"	let curpos = col('.')
"	if &l:et
"		call setline('.', repeat(' ', &l:ts) . getline('.'))
"		call cursor(0, curpos+&l:ts)
"	else
"		call setline('.', "\t" . getline('.'))
"		call cursor(0, curpos+1)
"	endif
"endfunction
"
"function! s:RmIndent()
"	"Remove a tab from beginning of line.  If spaces, then remove ts
"	"worth of spaces.  (Realigns first)  ts is used because
"	"this function is supposed to remove indentation.
"	"Tabs represent indentation, so use ts instead of sts
"	let curline = getline('.')
"	if len(curline)
"		let nremoved = 0
"		if curline[0] == "\t"
"			let nremoved = 1
"		elseif curline[0] == ' '
"			while nremoved < &l:ts
"				if curline[nremoved] == ' '
"					let nremoved += 1
"				else
"					break
"				endif
"			endwhile
"		endif
"		if nremoved
"			let curcol = col('.')
"			call setline('.', curline[nremoved:])
"			call cursor(0, curcol-nremoved)
"		endif
"	endif
"endfunction
"
"" realign current line
"nnoremap <C-K>a :call <SID>Realign()<CR>
"" Realign last visual selection
"nnoremap <C-K>A :'<lt>,'>call <SID>Realign()<CR>'<lt>
"
"if v:version > 801
"	inoremap <C-T> <Cmd>call<Space><SID>AddIndent()<CR>
"	inoremap <C-D> <Cmd>call<Space><SID>RmIndent()<CR>
"else
"	"If autoindented, <C-O> will delete all indentation
"	"use '<Space><BS>' to prevent that.
"	inoremap <C-T> <Space><BS><C-O>:call<Space><SID>AddIndent()<CR>
"	inoremap <C-D> <Space><BS><C-O>:call<Space><SID>RmIndent()<CR>
"endif
"
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
