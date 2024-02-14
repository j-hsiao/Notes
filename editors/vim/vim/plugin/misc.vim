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
"  <Leader>r: prompt to repeat a char by N times
"
"Abbreviations:
"  Inp:  Inputs header
"  Outp: Outputs header

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

"scratch buffer
if maparg('<Leader>b', 'n') == ''
	nnoremap <Leader>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>
endif

"counterpart to <C-H>
if maparg("\<C-L>", 'i') == ''
	inoremap <silent> <C-L> <Del>
endif

"Easier escape
if maparg(';l', 'i') == ''
	inoremap ;l <Esc>
endif

"Preserve a mapping to original <Leader>
if maparg('<Leader><Leader>', 'i') == ''
	execute jhsiaomapfallback#CreateFallback('<Leader><Leader>', '<Leader>', 'i')
endif

"Sectioning
function! s:IRepeatChar()
	call inputsave()
	let resp = input('repeat [count]char: ')
	call inputrestore()
	if strlen(resp)
		let repeat = strpart(resp, 0, strlen(resp)-1)
		if repeat == ''
			let repeat = 30
		endif
		return repeat(strpart(resp, strlen(resp)-1), repeat)
	endif
	return ''
endfunction

if maparg('<Leader>r', 'i') == ''
	inoremap <expr> <Leader>r <SID>IRepeatChar()
endif

for val in ['In', 'Out']
	if maparg(val . 'p', 'i', v:true) == ''
		execute 'inorea ' . val . 'p ' . val . 'puts<CR>' . repeat('=', strlen(val) + 4)
	endif
endfor

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
function! s:RmTrailSpace() range
	let curline = a:firstline
	while curline <= a:lastline
		call setline(curline, matchstr(getline(curline), '\m^.*\S'))
		let curline += 1
	endwhile
endfunction

function! s:AddCommentV()
	let parts = split(&l:commentstring, '%s')
	if len(parts) > 1
		"TODO commentstring has trailing info...
	endif
	let pre = parts[0]
	let firstline = line("'<")
	let lastline = line("'>")
	let commentcol = v:maxcol
	"If the selection starts on a blank line, then using <C-V>
	"for lazy comment might not work.  startline is not necessarily
	"the same as the '< mark.  Same for stopline and '>
	let startline = -1
	let stopline = 0
	while firstline <= lastline
		if getline(firstline) !~ '\m^\s*$'
			let commentcol = min([commentcol, indent(firstline)])
			if startline < 0
				let startline = firstline
			endif
			let stopline = firstline
		endif
		let firstline += 1
	endwhile
	if startline < 0
		return ''
	elseif commentcol == 0
		let cmd = [startline . 'gg']
		while startline <= stopline
			if getline(startline) =~ '\m^\s*\S'
				call add(cmd, '0i' . pre . "\<Esc>")
			endif
			if startline != stopline
				call add(cmd, 'j')
			endif
			let startline += 1
		endwhile
		call add(cmd, "'<")
		return join(cmd, '')
	else
		return startline . 'gg' . (commentcol+1) . "|\<C-V>"
			\ . stopline . 'gg$I' . pre . "\<Esc>"
	endif
endfunction

function! s:AddCommentI()
	let parts = split(&l:commentstring, '%s')
	if len(parts) > 1
		"TODO commentstring has trailing info...
	endif
	let pre = parts[0]
	let prespaces = matchstr(getline('.'), '\m^\s*')
	call jhsiaoinsert#InsertText(pre, strlen(prespaces))
	return ''
endfunction

inoremap <Plug>MiscAddComment; <C-R>=<SID>AddCommentI()<CR>
nmap <Plug>MiscAddComment; V<Plug>MiscAddComment;
nnoremap <expr> <Plug>MiscAddCommentVHelp; <SID>AddCommentV()
vmap <Plug>MiscAddComment; :call <SID>RmTrailSpace()<CR><Plug>MiscAddCommentVHelp;

"Uncomment current line(s)
function! s:RmCommentV() range
	let parts = split(&l:commentstring, '%s')
	if len(parts) > 1
		"TODO commentstring has trailing info...
	endif
	let fullpat = '\m^\(\s*\)' . parts[0]
	let strippedpat = substitute(fullpat, '\m\s*$', '', '')
	let curline = a:firstline
	while curline <= a:lastline
		let curtext = getline(curline)
		let result = substitute(curtext, fullpat, '\1', '')
		if result != curtext
			call setline(curline, result)
		else
			let result = substitute(curtext, strippedpat, '\1', '')
			if result != curtext
				call setline(curline, result)
			endif
		endif
		let curline += 1
	endwhile
endfunction

function! s:RmCommentI()
	let parts = split(&l:commentstring, '%s')
	if len(parts) > 1
		"TODO commentstring has trailing info...
	endif
	let fullpat = '\m^\s*' . parts[0]
	let curtext = getline('.')
	if curtext =~ fullpat
		call jhsiaoinsert#DeleteText(
			\ strlen(parts[0]),
			\ strlen(matchstr(curtext, '\m^\s*')))
	else
		let strippedpat = substitute(fullpat, '\m\s*$', '', '')
		if curtext =~ strippedpat
			call jhsiaoinsert#DeleteText(
				\ strlen(substitute(parts[0], '\m\s*$', '', '')),
				\ strlen(matchstr(curtext, '\m^\s*')))
		endif
	endif
	return ''
endfunction

inoremap <Plug>MiscRmComment; <C-R>=<SID>RmCommentI()<CR>
nmap <Plug>MiscRmComment; V<Plug>MiscRmComment;
vnoremap <Plug>MiscRmComment; :call <SID>RmCommentV()<CR>

for mode in ['i', 'n', 'v']
	let after = mode == 'v' ? 'n' : mode
	if maparg('<C-K>/', mode) == ''
		execute jhsiaocrepeat#CharRepeatedCmds(mode . 'map <C-K>/ <Plug>MiscAddComment;', '/', after)
	endif
	if maparg("<C-K><C-K>/", mode) == ''
		execute jhsiaocrepeat#CharRepeatedCmds(mode . 'map <C-K><C-K>/ <Plug>MiscRmComment;', '/', after)
	endif
endfor
