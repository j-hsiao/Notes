"NOTE: <expr> mappings do not allow modifications to text.
"However, insert mode <C-R>= can modify text and may be a better choice
"than using <C-O>:call since restoring the position after the <C-O> may
"result in incorrect cursor placement after the <C-O> command is
"finished.

if get(g:, 'loaded_jhsiaoutil', 0)
	finish
endif
let g:loaded_jhsiaoutil = 1

"Insert text in current line while keeping cursor in same position
function! jhsiaoutil#InsertText(text, bytepos)
	let curline = getline('.')
	let curpos = getpos('.')
	call setline('.', strpart(curline, 0, a:bytepos)
		\ . a:text . strpart(curline, a:bytepos))
	if a:bytepos < curpos[2]
		let curpos[2] += strlen(a:text)
		call setpos('.', curpos)
	endif
	return ''
endfunction

"Delete nbytes bytes from current line at bytepos position without
"changing the relative cursor position.
function! jhsiaoutil#DeleteText(nbytes, bytepos)
	let curline = getline('.')
	let curpos = getpos('.')
	call setline('.', strpart(curline, 0, a:bytepos)
		\ . strpart(curline, a:bytepos + a:nbytes))
	if a:bytepos < curpos[2]
		let curpos[2] -= min([curpos[2]-(a:bytepos+1), a:nbytes])
		call setpos('.', curpos)
	endif
	return ''
endfunction

"Shift cursor column to maintain relative position after an edit.
"position: position of change (in bytes, 0 indexed)
"nbytes: number of bytes changed, >0 = added, <0 = removed
"optional current cursor position (in bytes, 0-indexed)
"NOTE: if removing, then CursorShift should be called before
"removal.  Otherwise, when the cursor is at the end, removal will
"change the cursor position.  because it would have been past the end.
"When adding, it should be called after the change.  Otherwise, the
"CursorShift might try to move past the end of the current line.
function! jhsiaoutil#CursorShift(position, nbyteschanged, ...)
	if a:0
		let curpos = a:1
	else
		let curpos = col('.')-1
	endif
	if a:nbyteschanged > 0
		if curpos >= a:position
			let cur = getpos('.')
			let cur[2] += a:nbyteschanged
			call setpos('.', cur)
		endif
	else
		if a:position <= curpos
			let cur = getpos('.')
			let cur[2] += max([a:nbyteschanged, a:position-curpos])
			call setpos('.', cur)
		endif
	endif
endfunction


"TODO: parse comments and use that?
"Return a list:
"[leading comment char(s), whitespace, whitespace, end comment char(s)]
"The actual comment would go between the whitespace indices.
function! jhsiaoutil#GetCMSParts()
	return matchlist(&l:cms, '\m\(.*\S\)\(\s*\)\?%s\(\s*\)\?\(.*\)$')
endfunction

"Return pattern for analyzing a line of text using commentstring.
"0: the full match
"1: leading whitespace
"2: precomment string
"3: text
"4: postcomment string
"5: trailing text
function!  jhsiaoutil#GetCMSPattern()
	let parts = jhsiaoutil#GetCMSParts()

	let nmatchtrail = printf('\%%(\%%(%s\)\?\%%(\V%s\m\)\)', parts[3], parts[4])
	let indent = '\m^\(\s*\)'
	let precms = '\(\V%s\m\%%(%s\)\?\)\?'
	let text = '\(.*%s\@=\|.*%s\@!\)'
	let postcms = '\(\%%(%s\)\?\V%s\m\)\?'
	let extra = '\(.*\S\)\?'
	return printf(
		\ join([indent, precms, text, postcms, extra], ''),
		\ escape(parts[1], '\'),
		\ escape(parts[2], '\'),
		\ nmatchtrail, nmatchtrail,
		\ escape(parts[3], '\'),
		\ escape(parts[4], '\'))
endfunction
