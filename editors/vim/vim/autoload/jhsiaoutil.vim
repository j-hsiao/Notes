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

"flags:
"n	nested (recursive) comments
"b	add blank space after str
"f	only first line has char, but keep indent (not really a comment...
"	probably)
"s	start
"m	middle
"e	end
"l	left align (default)
"r	right align
"O	don't consider for O command
"x	type last char of end to add end
"digits offset from a left alignment
"
"NOTE: l, r say used with s or e, but experimenting,
"it only seems to ever have an effect if used with s
"using l and r with e does not seem to do anything.
"digits don't seem to do anything for e either...
"the example with ex-2:******/
"does not work as the example indicates.
"It is still left aligned with the middle parts...
function! jhsiaoutil#ParseComments()
	starts = []
	mids = []
	ends = []
	singles = []
	for part in split(&l:comments, ',', v:true)
		let [flags, chars] = split(part, ':', v:true)
		let fdict = {'str': chars}
		for flag in flags
			let fdict[flag] = v:true
		endfor
		if get(fdict, 's', 0)
			call add(starts, fdict)
		elseif get(fdict, 'm', 0)
			call add(mids, fdict)
		elseif get(fdict, 'e', 0)
			call add(ends, fdict)
		else
			call add(singles, fdict)
		endif
	endfor
	if len(starts) != len(mids) || len(mids) != len(ends)
		throw '3-piece comments must mach length'
	endif
	let i = 0
	let multis = []
	while i < len(starts)
		call add(multis, [starts[i], mids[i], ends[i]])
		let i += 1
	endwhile
	return [singles, multis]
endfunction

"TODO: parse comments and use that?
"Return a list:
"[leading comment char(s), whitespace, whitespace, end comment char(s)]
"The actual comment would go between the whitespace indices.
function! jhsiaoutil#GetCMSParts()
	let result = matchlist(&l:cms, '\m\(.*\S\)\(\s*\)\?%s\(\s*\)\?\(.*\)$')
	if len(result)
		return result
	else
		return repeat([''], 5)
	endif
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
