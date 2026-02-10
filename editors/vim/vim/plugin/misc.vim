"Miscellaneous mappings and settings
"These usually begin with <Leader>
"
"normal  mode mappings
"  <Leader>?: print out nmaps starting with <Leader>
"  <C-[><C-[>: :nohl
"  <Leader>b: open a scratch buffer
"
"insert mode mappings
"  ;l -> <Esc>
"  <C-L>: <Del>
"  <Leader><Leader>: original <Leader> key

if get(g:, 'loaded_misc', 0)
	finish
endif
let g:loaded_misc = 1

"basic options
if maparg('<Leader>?', 'n') == ''
	nnoremap <Leader>? :nnoremap <lt>Leader><CR>
endif
if maparg('<Leader>?', 'i') == ''
	if strlen("\<Cmd>") == strlen("<Cmd>")
		inoremap <Leader>? <Cmd>inoremap <lt>Leader><CR>
	else
		inoremap <Leader>? <C-O>:inoremap <lt>Leader><CR>
	endif
endif

"cancel search highlights
if maparg("\<C-[>\<C-[>", 'n') == ''
	nnoremap <silent> <C-[><C-[> :nohl<CR>
endif
if maparg("\<Esc>\<Esc>", 'n') == ''
	nnoremap <silent> <Esc><Esc> :nohl<CR>
endif

"scratch buffer
if maparg('<Leader>b', 'n') == ''
	nnoremap <Leader>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>
endif

"counterpart to <C-H>
if maparg("\<C-L>", 'i') == ''
	inoremap <silent> <C-L> <Del>
endif

"Easier escape
"if maparg(';l', 'i') == ''
"	inoremap ;l <Esc>
"endif

"Preserve a mapping to original <Leader>
if maparg('<Leader><Leader>', 'i') == ''
	execute jhsiaomapfallback#CreateFallback('<Leader><Leader>', '<Leader>', 'i')
endif

"gq uses textwidth but textwidth also has the possibly undesired effect
"of forcing newline when reaching the column.  This allows using a
"prefix count to gq to specify the textwidth for the gq command.
"restore textwidth afterwards
let s:gqwidth = 0
function! s:FitWidth(...)
	if a:0
		call feedkeys(
			\ ":setl textwidth=" . s:gqwidth . "\<CR>'[gq']:setl textwidth="
			\ . &l:textwidth . "\<CR>", 'n')
	else
		if v:count != v:count1
			if &l:textwidth
				let s:gqwidth = &l:textwidth
			else
				let s:gqwidth = 72
			endif
		else
			let s:gqwidth = v:count
		endif
		return 'g@'
	endif
endfunction
nnoremap <expr> gq ":<Bslash><lt>C-U>setl<Space>opfunc=<SID>FitWidth<Bslash><lt>CR>" . <SID>FitWidth()

function! s:BlockStart(start, stop)
	let targetcol = -1
	let check = a:start
	while check <= a:stop
		let parts = matchlist(getline(check), '\m^\(\s*\)\(.*\)')
		if strlen(parts[2])
			let curcol = strdisplaywidth(parts[1])
			if curcol < targetcol || targetcol < 0
				let targetcol = curcol
			endif
		endif
		let check += 1
	endwhile
	return targetcol
endfunction

"Comment manipulation only operate on whole lines.
"unless a comment includes an entire line, it will not be considered.
"undefined behavior otherwise.
"
"Comment current line(s)
"visual mode:
"	strip trailing whitespace
"	add comment to left-most non-white-space col of the selected lines
"normal mode:
"	operator-func comment traversed lines
"insert mode:
"	current line is purely whitespace, add coment char in current position
"	otherwise, add comment char to first non-white-space char of the
"	current line.
function! s:AddCommentV() range
	let [singles, multis] = jhsiaoutil#ParseComments()
	let targetcol = s:BlockStart(a:firstline, a:lastline)
	if len(singles)
		let pre = singles[0]['val']
		if singles[0]['flags'] =~ 'b'
			let pre .= ' '
		endif
		let mid = pre
		let end = ''
	else
		let pre = multis[0]['s']['add']
		let mid = multis[0]['m']['add']
		let end = multis[0]['e']['val']
	endif
	let check = a:firstline
	while check <= a:lastline
		let curline = getline(check)
		if strlen(curline)
			let [prewidth, splitidx] = jhsiaoutil#FindColumn(curline, targetcol)
			if splitidx == 0
				call setline(check, pre . curline)
			else
				if prewidth == targetcol
					call setline(check, join([curline[:splitidx-1], curline[splitidx:]], pre))
				else
					let parts = [
						\ curline[:splitidx-1],
						\ repeat(' ', targetcol-prewidth), pre,
						\ repeat(' ', &l:ts + prewidth - targetcol),
						\ curline[splitidx+1:]]
					call setline(check, join(parts, ''))
				endif
			endif
			let pre = mid
		endif
		if check == a:lastline && strlen(end)
			call setline(check, getline(check) . end)
		endif
		let check += 1
	endwhile
	exe a:firstline 'mark ['
	exe a:lastline 'mark ]'
endfunction

function! s:AddCommentLine()
	let [singles, multis] = jhsiaoutil#ParseComments()
	let parts = matchlist(getline('.'), '\m^\(\s*\)\(.*\)')
	if len(singles)
		let prefix = singles[0]['val']
		if singles[0]['flags'] =~ 'b'
			let prefix .= ' '
		endif
		call setline('.', join(parts[1:2], prefix))
	else

		let prefix = multis[0]['s']['add']
		call setline(
			\ '.', join([parts[1], prefix, parts[2], multis[0]['e']['val']], ''))
	endif
	call jhsiaoutil#CursorShift(strlen(parts[1]), strlen(prefix))
	return ''
endfunction

inoremap <Plug>MiscAddComment; <C-R>=<SID>AddCommentLine()<CR>
nmap <Plug>MiscAddComment; :call <SID>AddCommentLine()<CR>
vmap <Plug>MiscAddComment; :call <SID>AddCommentV()<CR>


"Remove a multi-line comment from start to min(ending, stop).
"start: start of selection
"stop: end of selection
"ending: ending line of multiline comment.
"muulti: multi info dict.
function! s:ClearMulti(start, stop, ending, multi)
	let cur = a:start
	while cur <= a:ending
		if cur > a:stop
			call s:AddMultiBeg(cur, a:multi)
			return cur
		else
			let parts = matchlist(getline(cur), a:multi['reg'])
			if strlen(parts[4]) || strlen(parts[6])
				call setline(cur, join([parts[1], parts[4], parts[6]], ''))
			else
				call setline(cur, '')
			endif
		endif
		let cur += 1
	endwhile
	return a:ending + 1
endfunction

"Remove commenting from line curno.
"If multi, then remove from current line until end if applicable
"Return the next line to handle.
function! s:RmLineV(curno, singles, multis, start, stop)
	let curtext = getline(a:curno)
	for multi in a:multis
		let parts = matchlist(curtext, multi['reg'])
		if strlen(parts[2])
			if strlen(parts[5])
				call setline(a:curno, join([parts[1], parts[4], parts[6]], ''))
				return a:curno + 1
			else
				let ending = jhsiaoutil#MultiEnd(a:curno+1, multi)
				if ending > 0
					call setline(a:curno, join([parts[1], parts[4], parts[6]], ''))
					return s:ClearMulti(a:curno+1, a:stop, ending, multi)
				endif
			endif
		elseif (
				\ strlen(parts[3])
				\ && a:curno == a:start
				\ && jhsiaoutil#MultiStart(a:curno, multi)>0)
			if strlen(parts[5])
				call s:AddMultiEnd(a:curno-1, multi)
				if strlen(parts[4]) || strlen(parts[6])
					call setline(a:curno, join([parts[1], parts[4], parts[6]], ''))
				else
					call setline(a:curno, '')
				endif
				return a:curno+1
			else
				let ending = jhsiaoutil#MultiEnd(a:curno+1, multi)
				if ending > 0
					call s:AddMultiEnd(a:curno-1, multi)
					if strlen(parts[4]) || strlen(parts[6])
						call setline(a:curno, join([parts[1], parts[4], parts[6]], ''))
					else
						call setline(a:curno, '')
					endif
					return s:ClearMulti(a:curno+1, a:stop, ending, multi)
				endif
			endif
		endif
	endfor
	for single in a:singles
		let parts = matchlist(curtext, single['reg'])
		if len(parts)
			call setline(a:curno, join([parts[1], parts[3]], ''))
			return a:curno + 1
		endif
	endfor
	return a:curno+1
endfunction


"Uncomment current line(s)
function! s:RmCommentV() range
	let [singles, multis] = jhsiaoutil#ParseComments()
	let curno = a:firstline
	while curno <= a:lastline
		let curline = getline(curno)
		let curno = s:RmLineV(curno, singles, multis, a:firstline, a:lastline)
	endwhile
	exe a:firstline 'mark ['
	exe a:lastline 'mark ]'
endfunction


"Add multi to end of given line
function! s:AddMultiEnd(lineno, multi)
	let check = a:lineno
	while check > 0
		let text = getline(check)
		let parts = matchlist(text, a:multi['reg'])
		if strlen(parts[2]) && strlen(parts[4]) == 0
			call setline(check, '')
			return
		elseif strlen(parts[4])
			call setline(check, text . a:multi['e']['val'])
			return
		else
			call setline(check, '')
			let check -= 1
		endif
	endwhile
endfunction

"Add multi to start to beginning of given or next lines
function! s:AddMultiBeg(lineno, multi)
	let check = a:lineno
	while 1
		let text = getline(check)
		let parts = matchlist(text, a:multi['reg'])
		if strlen(parts[5]) && strlen(parts[4]) == 0
			call setline(check, '')
			return
		elseif strlen(parts[4])
			let pre = a:multi['s']['add']
			call setline(check, join([parts[1], pre, parts[4], parts[5], parts[6]], ''))
			return
		else
			call setline(check, '')
			let check += 1
		endif
	endwhile
endfunction

"Remove a multi-line comment and adjust cursor position.
"Assume lineno is indeed inside a 3-part comment
"Removing a single multi-line comment may require modifying
"other lines.
function! s:RmMulti(lineno, multi, parts, shift)
	if strlen(a:parts[5]) == 0
		call s:AddMultiBeg(a:lineno+1, a:multi)
	endif
	if strlen(a:parts[2]) == 0
		call s:AddMultiEnd(a:lineno-1, a:multi)
	endif
	if a:shift
		call jhsiaoutil#CursorShift(
			\ strlen(a:parts[1]),
			\ -(strlen(a:parts[2])+strlen(a:parts[3])))
		call jhsiaoutil#CursorShift(
			\ strlen(a:parts[1]) + strlen(a:parts[4]),
			\ -strlen(a:parts[5]))
	endif
	call setline(a:lineno, join([a:parts[1], a:parts[4], a:parts[6]], ''))
endfunction

function! s:RmCommentLine()
	let [singles, multis] = jhsiaoutil#ParseComments()
	let curline = getline('.')
	for single in singles
		let parts = matchlist(curline, single['reg'])
		if len(parts)
			call jhsiaoutil#CursorShift(strlen(parts[1]), -strlen(parts[2]))
			call setline('.', join([parts[1], parts[3]], ''))
			return ''
		endif
	endfor
	"To check if current line is multi-comment, must find the comment start.
	"and comment end...
	let lineno = line('.')
	for multi in multis
		let parts = matchlist(curline, multi['reg'])
		if strlen(parts[2]) || strlen(parts[5]) || (strlen(parts[3]) && jhsiaoutil#MultiStart(lineno, multi)>0)
			call s:RmMulti(lineno, multi, parts, v:true)
		endif
	endfor
	return ''
endfunction

inoremap <Plug>MiscRmComment; <C-R>=<SID>RmCommentLine()<CR>
nmap <Plug>MiscRmComment; :call <SID>RmCommentLine()<CR>
vnoremap <Plug>MiscRmComment; :call <SID>RmCommentV()<CR>

for mode in ['i', 'n', 'v']
	let after = mode == 'v' ? 'n' : mode
	if maparg('<Leader>/', mode) == ''
		execute jhsiaocrepeat#CharRepeatedCmds(mode . 'map <Leader>/ <Plug>MiscAddComment;', '/', after)
	endif
	if maparg("<Leader>k/", mode) == ''
		execute jhsiaocrepeat#CharRepeatedCmds(mode . 'map <Leader>k/ <Plug>MiscRmComment;', '/', after)
	endif
endfor


"------------------------------
"Surround visual selection with chars.
"------------------------------

"Surround the visual selection with given character.
"If only char1 is given, use that on both ends.
"Otherwise, use char1 before selection and second arg after.
function! s:Surround(char1, ...)
	if a:0
		let ending = a:1
	else
		let ending = a:char1
	endif
	if exists('*virtcol')
		let col1 = virtcol('v')
		let col2 = virtcol('.')
	else
		let curline = getline('.')
		let col1 = strdisplaywidth(strpart(curline, 0, col('v')))
		let col2 = strdisplaywidth(strpart(curline, 0, col('.')))
	endif
	if col2 < col1
		let [col1,col2] = [col2, col1]
	endif
	return printf("\<Esc>%s|a%s\<Esc>%s|i%s\<Esc>", col2, ending, col1, a:char1)
endfunction

if maparg("<Leader>'", 'v') == ''
	vnoremap <expr> <Leader>' <SID>Surround("'")
endif
if maparg('<Leader>"', 'v') == ''
	vnoremap <expr> <Leader>" <SID>Surround('"')
endif
if maparg('<Leader>(', 'v') == ''
	vnoremap <expr> <Leader>( <SID>Surround('(', ')')
endif
if maparg('<Leader>[', 'v') == ''
	vnoremap <expr> <Leader>[ <SID>Surround('[', ']')
endif

" Add header wrappers.
" atend: move cursor to the end.
" top: add above
" bottom: add below
function! s:FormatHeader(top, bottom, atend, handle_comments)
	if a:atend
		call s:FormatHeader(a:top, a:bottom, v:false, a:handle_comments)
		if a:bottom
			normal j$
		endif
		return
	endif
	let ch = nr2char(getchar())
	let lineno = line('.')
	let pattern = '\m^\([[:blank:]]*\)\(.*\)$'
	let curline = matchlist(getline('.'), pattern)
	let indentcols = strdisplaywidth(curline[1])
	let textcols = strdisplaywidth(curline[2], indentcols)

	let comm = ''
	let wrapper = curline[1] . repeat(ch, textcols)
	if a:handle_comments
		for cmnt in split(&comments, ',')
			let info = split(cmnt, ':', v:true)
			let nmatch = matchlist(curline[1] . curline[2], '\m\([[:blank:]]*\)\V\(' . escape(info[1], '\') . '\m[[:blank:]]*\)\(.*\)')
			if len(nmatch)
				let comm = nmatch[2]
				let wrapper = curline[1] . comm . repeat(ch, textcols - strdisplaywidth(comm, indentcols))
				break
			endif
		endfor
	endif
	if a:bottom
		let nxtline = matchlist(getline(lineno+1), pattern)
		let nxtsep = nxtline[1] == curline[1] && strlen(nxtline[2]) > 0
			\ && match(nxtline[2], '\V\^' . escape(comm, '\') . escape(nxtline[2][-1:], '\') . '\*\$') >= 0
	endif
	if a:top
		if lineno > 1
			let preline = matchlist(getline(lineno-1), pattern)
			if preline[1] == curline[1] && strlen(preline[2]) > 0
				\ && match(preline[2], '\V\^' . escape(comm, '\') . escape(preline[2][-1:], '\') . '\*\$') >= 0
				if ! a:bottom
					call setline(lineno-1, wrapper)
					return
				elseif nxtsep
					call setline(lineno+1, wrapper)
					call setline(lineno-1, wrapper)
					return
				endif
			endif
		endif
	elseif a:bottom && nxtsep
		call setline(lineno+1, wrapper)
		return
	endif
	if a:bottom
		call append(lineno, wrapper)
	endif
	if a:top
		call append(lineno-1, wrapper)
	endif
endfunction

" Surround header (new delimiters)
if maparg('<Leader>h', 'n') == ''
	nnoremap <Leader>h :call <SID>FormatHeader(1, 1, v:false, v:false)<CR>
	nnoremap <Leader>H :call <SID>FormatHeader(1, 1, v:false, v:true)<CR>
	nnoremap <Leader>y :call <SID>FormatHeader(1, 0, v:false, v:false)<CR>
	nnoremap <Leader>Y :call <SID>FormatHeader(1, 0, v:false, v:true)<CR>
	nnoremap <Leader>n :call <SID>FormatHeader(0, 1, v:false, v:false)<CR>
	nnoremap <Leader>N :call <SID>FormatHeader(0, 1, v:false, v:true)<CR>
endif

if maparg('<Leader>h', 'i') == ''
	inoremap <Leader>h <C-O>:call <SID>FormatHeader(1, 1, v:true, v:false)<CR>
	inoremap <Leader>H <C-O>:call <SID>FormatHeader(1, 1, v:true, v:true)<CR>
	inoremap <Leader>y <C-O>:call <SID>FormatHeader(1, 0, v:true, v:false)<CR>
	inoremap <Leader>Y <C-O>:call <SID>FormatHeader(1, 0, v:true, v:true)<CR>
	inoremap <Leader>n <C-O>:call <SID>FormatHeader(0, 1, v:true, v:false)<CR>
	inoremap <Leader>N <C-O>:call <SID>FormatHeader(0, 1, v:true, v:true)<CR>
endif


"------------------------------
" Change :u<CR> to :up<CR>
" usually would never use :u command since you could just press u in
" normal mode instead, :u is probably more often simply because didn't
" type the p for the :up command.
"------------------------------
nnoremap :u<CR> :up<CR>

"Make insert-mode C-u and C-w  undoable
execute jhsiaoextendmap#ExtendMap("<C-U>", 'i', '<C-G>u', v:true)
execute jhsiaoextendmap#ExtendMap("<C-W>", 'i', '<C-G>u', v:true)

" Set the ' mark when number + j/k
function! s:JumpJK(rep, key)
	if a:rep != 0
		return "m'" . a:rep . a:key
	else
		return a:key
	endif
endfunction
nnoremap <expr> j <SID>JumpJK(v:count, "j")
nnoremap <expr> k <SID>JumpJK(v:count, "k")


" For some weird reason, on debian?linux?ubuntu?wsl?...
" from insert mode, <C-[> followed by O will enter some weird
" state as if there is some kind of mapping. It will wait for
" more keys, and, for example: will insert a 1 and
" <C-[>Oq 
" q: 1
" w: 7
" r: 2
" t: 4
" u: 5
" o: /
" p: 0
" Q: <F2>
" R: <F3>
" ...
" it does not break undo...
" and then return back to insert mode1asdf
" It only happens if .vimrc exists, even if it is completely empty.
" use this mapping to prevent this weird behavior
inoremap <C-[>O <C-[>O
