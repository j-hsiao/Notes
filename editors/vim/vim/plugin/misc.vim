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

"Future work: maybe consider indentation/alignment to determine
"if any trailing spaces from splitting &l:cms should be removed
"as well.
"Comment current line(s)
function! s:AddComment(mode)
	let pre = split(&l:commentstring, '%s')[0]
	let check = substitute(pre, '\m\s*$', '', '')
	if a:mode == 'v'
		if line('v') < line('.')
			let firstline = line('v')
			let lastline = line('.')
		else
			let firstline = line('.')
			let lastline = line('v')
		endif
		let commentcol = -1
		let curline = firstline
		while curline <= lastline
			if getline(curline) !~ '\m^\s*$'
				let curcol = indent(curline)
				if curcol < commentcol || commentcol < 0
					let commentcol = curcol
				endif
			endif
			let curline += 1
		endwhile
		let curline = firstline
		let start = -1
		let stop = -1
		while curline <= lastline
			if indent(curline) >= commentcol
				if start < 0
					let start = curline
				endif
				let stop = curline
			endif
			let curline += 1
		endwhile
		let commentcol += 1
		return "\<Esc>" . start . 'gg' . commentcol . "|\<C-V>"
			\ . stop . 'gg$' . commentcol . '|I' . pre . "\<Esc>"
	else
		let prespaces = matchstr(getline('.'), '\m^\s*')
		let charskip = (col('.')-1)
		if charskip >= strlen(prespaces)
			let charskip += strlen(pre)
		endif
		if a:mode == 'i'
			return "\<C-O>I" . pre . "\<C-O>0" . repeat("\<Right>", charskip)
		elseif a:mode == 'n'
			return 'I' . pre . "\<Esc>0" . charskip . 'l'
		endif
	endif
endfunction

inoremap <expr> <Plug>MiscAddComment; <SID>AddComment('i')
nnoremap <expr> <Plug>MiscAddComment; <SID>AddComment('n')
vnoremap <expr> <Plug>MiscAddComment; <SID>AddComment('v')

"Uncomment current line(s)
function! s:RmComment(mode) range
	let pre = split(&l:commentstring, '%s')[0]
	let check = substitute(pre, '\m\s*$', '', '')
	if a:mode == 'v'
		let firstline = a:firstline
		while firstline <= a:lastline
			if getline(firstline) =~ '\m^\s*' . pre
				call setline(firstline, substitute(getline(firstline), '\m^\(\s*\)' . pre, '\1', ''))
			elseif getline(firstline) =~ '\m^\s*' . check
				call setline(firstline, substitute(getline(firstline), '\m^\(\s*\)' . check, '\1', ''))
			endif
			let firstline += 1
		endwhile
	else
		if getline('.') !~ '\m^\s*' . check
			return ''
		endif
		let prespaces = strlen(matchstr(getline('.'), '\m^\s*'))
		let ndel = strlen(check)
		if getline('.') =~ '\m^\s*' . pre && getline('.') !~'\m^\s*' . pre . '\s'
			let ndel = strlen(pre)
		endif
		let npos = col('.')-1
		if a:mode == 'i'
			let cmd = "\<C-O>_" . repeat("\<Del>", ndel)
			if npos < prespaces
				return cmd . repeat("\<Left>", prespaces - npos)
			elseif prespaces + ndel < npos
				return cmd . repeat("\<Right>", npos - (prespaces + ndel))
			else
				return cmd
			endif
		elseif a:mode == 'n'
			let cmd = '_' . ndel . 'x'
			if npos < prespaces
				return cmd . (prespaces-npos) . 'h'
			elseif prespaces + ndel < npos
				return cmd . (npos - (prespaces + ndel)) . 'l'
			else
				return cmd
			endif
		endif
	endif
endfunction

inoremap <expr> <Plug>MiscRmComment; <SID>RmComment('i')
nnoremap <expr> <Plug>MiscRmComment; <SID>RmComment('n')
vnoremap <Plug>MiscRmComment; :call<SID>RmComment('v')<CR>

for mode in ['i', 'n', 'v']
	let after = mode == 'v' ? 'n' : mode
	if maparg('<C-K>/', mode) == ''
		execute crepeat#CharRepeatedCmds(mode . 'map <C-K>/ <Plug>MiscAddComment;', '/', after)
	endif
	if maparg("<C-K><C-K>/", mode) == ''
		execute crepeat#CharRepeatedCmds(mode . 'map <C-K><C-K>/ <Plug>MiscRmComment;', '/', after)
	endif
endfor
