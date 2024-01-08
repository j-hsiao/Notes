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
	execute mapfallback#CreateFallback('<Leader><Leader>', '<Leader>', 'i')
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
"prefix count to gq to specify the width
function! s:FitWidth()
	execute 'autocmd CursorMoved <buffer> ++once :setlocal textwidth=' . &l:textwidth
	let width = v:count
	if v:count != v:count1
		if &l:textwidth
			let width = &l:textwidth
		else
			let width = 72
		endif
	endif
	execute 'setlocal textwidth=' . width
	" escape to consume the v:count if any
	return "\<Esc>gq"
endfunction

nnoremap <expr> gq <SID>FitWidth()

"Add comment string to lines
"function! s:AddComment(mode) range
"	let pre = split(&l:commentstring, '%s')[0]
"	let check = substitute(pre, '\m\s*$', '', '')
"	if a:mode == 'v'
"		let firstline = a:firstline
"		while firstline <= a:lastline
"			if getline(firstline) !~ '\m^\s*' . check && getline(firstline) !~ '\m^\s*$'
"				call setline(firstline, substitute(getline(firstline), '\m^\(\s*\)', '\1' . pre, ''))
"			endif
"			let firstline += 1
"		endwhile
"	else
"		if getline('.') =~ '\m^\s*' . pre
"			return ''
"		endif
"		let prespaces = matchstr(getline('.'), '\m^\s*')
"		let motion = col('.') . '|'
"		if col('.')-1 > strlen(prespaces)
"			let motion = (col('.') + strlen(pre)) . '|'
"		endif
"		if a:mode == 'i'
"			return "\<C-O>I" . pre . "\<C-O>" . motion
"		elseif a:mode == 'n'
"			return 'I' . pre . "\<Esc>" . motion
"		endif
"	endif
"endfunction
"
"inoremap <expr> <Plug>MiscAddComment; <SID>AddComment('i')
"nnoremap <expr> <Plug>MiscAddComment; <SID>AddComment('n')
"vnoremap <Plug>MiscAddComment; :call<SID>AddComment('v')<CR>
"
"if maparg('<C-K>/', 'i') == ''
"	imap <C-K>/ <Plug>MiscAddComment;
"endif
"if maparg('<C-K>/', 'n') == ''
"	nmap <C-K>/ <Plug>MiscAddComment;
"endif
"if maparg('<C-K>/', 'v') == ''
"	vmap <C-K>/ <Plug>MiscAddComment;
"endif


"function! s:RmComment(mode) range
"	let pre = split(&l:commentstring, '%s')[0]
"	let check = substitute(pre, '\m\s*$', '', '')
"	if a:mode == 'v'
"		let firstline = a:firstline
"		while firstline <= a:lastline
"			if getline(firstline) =~ '\m^\s*' . pre
"				call setline(firstline, substitute(getline(firstline), '\m^\(\s*\)' . pre, '\1', ''))
"			elseif getline(firstline) =~ '\m^\s*' . check
"				call setline(firstline, substitute(getline(firstline), '\m^\(\s*\)' . check, '\1', ''))
"			endif
"			let firstline += 1
"		endwhile
"	else
"		if getline('.') !~ '\m^\s*' . check
"			return ''
"		endif
"		let prespaces = matchstr(getline('.'), '\m^\s*')
"		let ndel = strlen(check)
"		if getline('.') =~ '\m^\s*' . pre
"			let ndel = strlen(pre)
"		endif
"
"		let motion = col('.') . '|'
"		if strlen(prespaces) + ndel < col('.')
"			let motion = (col('.') - ndel) . '|'
"		elseif strlen(prespaces) < col('.')
"			let motion = (strlen(prespaces)) . '|'
"		endif
"
"		if a:mode == 'i'
"			let ndel = strlen(check)
"			if getline('.') =~ '\m^\s*' . pre
"				let ndel = strlen(pre)
"			endif
"			let prespace = matchstr(getline('.'), '\m^\s*')
"			return "\<C-O>_" . repeat("\<Del>", ndel) . repeat("\<Right>", col('.') - 1 - (ndel + strlen(prespace)))
"		elseif a:mode == 'n'
"			let ndel = strlen(check)
"			if getline('.') =~ '\m^\s*'.pre
"				let ndel = strlen(pre)
"			endif
"			return '_' . ndel . 'x' . (col('.')-ndel) . '|'
"		endif
"	endif
"endfunction
"
"inoremap <expr> <C-K>' <SID>RmComment('i')
"nnoremap <expr> <C-K>' <SID>RmComment('n')
"vnoremap <C-K>' :call<SID>RmComment('v')<CR>
