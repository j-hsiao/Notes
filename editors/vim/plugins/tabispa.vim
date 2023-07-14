"TABIndentSPaceAlignmetn
"Use tab characters for indentation
"Use spaces for alignment
"effectively:
"tab key = alignment (always spaces)
"i_CTRL-T, i_CTRL-D for indent in insert mode
">>, << for indent in normal mode

function! s:DoTab()
	"Add spaces to next tabstop
	let step = &l:sts
	if step < 0
		let step = &l:sw
	endif
	if step == 0
		let step = &l:ts
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
