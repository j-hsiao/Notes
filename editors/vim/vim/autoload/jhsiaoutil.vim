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

"TODO insert at a visual column
"natural result seems to be if a tab
"replace tab with ts spaces
"and then insert accordingly

" vim       sO:" -,mO:"  ,eO:"",:"
" c         sO:* -,mO:*  ,exO:*/,s1:/*,mb:*,ex:*/,://
" html      s:<!--,m:    ,e:-->
" ptyhon    b:#,fb:-
" bash      s1:/*,mb:*,ex:*/,://,b:#,:%,:XCOMM,n:>,fb:-

"flags:
"	n   nested (recursive) comments
"	b   add blank space after str
"	f   only first line has char, but keep indent (not really a comment...
"	    probably)
"	s   start
"	m   middle
"	e   end
"	l   left align (default)
"	r   right align
"	O   don't consider for O command
"	x   type last char of end to add end
"digits offset from a left alignment
"
"NOTE: l, r, digits say used with s or e, but experimenting, it only
"seems to ever have an effect if used with s.  e always ends up with
"the end comment being left aligned to the middle comment.
"
"bash: &l:cms='#%s' but &l:com is /*,*,*/,//,#,XCOMM,>,...
"If cms is single, prefer it.  Otherwise, choose best single
"from com.
"
"regarding the b flag, if the comment char is single,
"whether a blank exists or not probably does not impact whether it is
"commented or not.  b seems to only actually impact comment-ness if it
"is desired after an m part of 3-part comment, so only enforce it there.
"m should probably only be processed if all relevant lines have m.  Otherwise
"it might be unrelated ex.
"	c contains s1:/*,mb:*,ex:*/.
"	but that means if you do something like
"		result = (something
"			+ something
"			* something else
"			/ other);
"	the line starting with * gets detected as an m part of 3-part comment.
"
"Return 2 lists: [single, multi]
"single: each item is a dict with keys:
"	flags: the flags str.
"	val: the comment value as parsed from &l:comments
"	reg: a regex pattern for detecting this item with the following groups:
"		1: leading whitespace
"		2: the comment character + any space
"		3: the text
"multi: each item is a dict with keys:
"	s: {flags: flags, val: chars}
"	m: {flags: flags, val: chars}
"	e: {flags: flags, val: chars}
"	reg: a regex for detecting these with groups:
"		1: leading whitespace
"		2: the s str and any potential whitespace
"		3: the m str and any potential whitespace
"		4: the text that is commented
"		5: the ending if it exists
"		6: anything after the ending if it exists
"
"comment removal requires both start and end for single line.
"single contains comments that are single.
"multi contains comments that have start, middle, end
function! jhsiaoutil#ParseComments()
	"comments and commentstring are unlikely to change while in the
	"same buffer, so try cache result
	let result = get(b:, 'jhsiaoutilParseCommentsResult', [])
	if len(result)
		return result
	endif
	let singles = []
	let multis = []
	let multimaybe = []
	let singlemaybe = []
	let multi = []
	let parts = split(&l:cms, '%s')
	if len(parts)
		let raws = substitute(parts[0], '\m^\s*\(.\{-}\)\s*$', '\1', '')
	endif
	if len(parts) == 1
		if parts[0] =~ '\m.*\s$'
			let pre = printf('b:%s', raws)
		else
			let pre = printf(':%s', raws)
		endif
		let comlist = join([pre, &l:comments], ',')
	elseif len(parts) == 2
		if parts[0] =~ '\m.*\s$'
			let s = printf('sr:%s', raws)
			let m = 'mb:' . repeat(' ', strlen(raws))
		else
			let s = printf('sr:%s', raws)
			let m = 'm:' . repeat(' ', strlen(raws))
		endif
		let e = printf('e:%s', substitute(parts[1], '\m^\s*\(.\{-}\)\s*$', '\1', ''))
		let comlist = join([s, m, e, &l:comments], ',')
	else
		let comlist = &l:comments
	endif
	for part in split(comlist, ',', v:true)
		let [flags, chars] = matchlist(part, '\m^\([^:]*\):\(.*\)$')[1:2]
		let info = {
			\ 'flags': flags,
			\ 'val': chars}
		if flags =~ 's'
			let multi = [info]
		elseif flags =~ 'm'
			call add(multi, info)
		elseif flags =~ 'e'
			call add(multi, info)
			if len(multi) != 3
				throw "3-part comments need 3 parts."
			endif
			let sreg = printf('\V%s\m', escape(multi[0]['val'], '\'))
			if multi[0]['flags'] =~ 'b'
				let sreg = sreg . '\s\?'
			endif
			let npre = 0
			if multi[0]['flags'] =~ '\m[0-9]\+'
				let npre = matchstr(multi[0]['flags'], '\m[0-9]\+')
			elseif multi[0]['flags'] =~ 'r'
				let npre = strdisplaywidth(multi[0]['val']) - strdisplaywidth(multi[1]['val'])
			endif
			let mreg = printf('\V%s%s\m', repeat(' ', npre), escape(multi[1]['val'], '\'))
			if multi[1]['flags'] =~ 'b'
				let mreg .= '\%(\s\|$\)'
			endif
			let ereg = printf('\V%s\m', escape(multi[2]['val'], '\'))
			let spaceuntil = printf('\(\s*\%%(%s\|%s\)\@=\|\s*\%%(%s\|%s\)\@!\)', sreg, mreg, sreg, mreg)
			let front = printf('\%%(\(%s\)\|\(%s\)\)\?', sreg, mreg)
			let texttil = printf('\(\%%(\%%(%s\)\@!.\)*\)', ereg)
			let reg = printf('%s%s%s\(%s\)\?\(.*\)', spaceuntil, front, texttil, ereg)
			let any = printf('^\s*\(%s\)\?\%%(\%%(%s\)\@!.\)*\(%s\)\?', sreg, ereg, ereg)
			let info = {'s': multi[0], 'm': multi[1], 'e': multi[2], 'reg': reg, 'any': any}
			if info['s']['flags'] =~ 'b' ||
				\ (info['m']['flags'] =~ 'b'
				\ && strlen(info['s']['val']) == strlen(info['m']['val'])+npre)
				let info['s']['add'] = info['s']['val'] . ' '
			else
				let info['s']['add'] = info['s']['val']
			endif
			if info['m']['flags'] =~ 'b' ||
				\ (info['s']['flags'] =~ 'b'
				\ && strlen(info['s']['val']) == strlen(info['m']['val'])+npre)
				let info['m']['add'] = repeat(' ', npre) . info['m']['val'] . ' '
			else
				let info['m']['add'] = repeat(' ', npre) . info['m']['val']
			endif
			if flags =~ '[fO]'
				call add(multimaybe, info)
			else
				if len(multis) > 0 && multis[0]['s']['val'] == info['s']['val']
					let multis[0] = info
				else
					call add(multis, info)
				endif
			endif
		else
			if flags =~ 'b'
				let info['reg'] = printf('^\(\s*\)\(\V%s\s\?\m\)\(.*\)', escape(chars, '\'))
			else
				let info['reg'] = printf('^\(\s*\)\(\V%s\m\)\(.*\)', escape(chars, '\'))
			endif
			if flags =~ '[fO]'
				call add(singlemaybe, info)
			else
				if len(singles) > 0 && singles[0]['val'] == info['val']
					let singles[0] = info
				else
					call add(singles, info)
				endif
			endif
		endif
	endfor
	if len(multis) == 0
		let multis = multimaybe
	endif
	if len(singles) == 0
		let singles = singlemaybe
	endif
	let b:jhsiaoutilParseCommentsResult = [singles, multis]
	return b:jhsiaoutilParseCommentsResult
endfunction

"Return a list of [[info, endline]...] 3-part comments that
"the given line may be strictly in the middle of.
function! jhsiaoutil#MidMulti(line, multis, ...)
	if a:0
		let maxdif = a:1
	else
		let maxdif = 1000
	endif
	let result = []
	for multi in a:multis
		if jhsiaoutil#MultiStart(a:line, multi) > 0
			let multiend = jhsiaoutil#MultiEnd(a:line, multi)
			if multiend > 0
				call add(result, [multi, multiend])
			endif
		endif
	endfor
	return result
endfunction

"Find the comment dict from singles/multis that matches the given line.
"Return list of [info, parts] for matching comment types
function! jhsiaoutil#MatchComment(line, singles, multis, ...)
	let ret = []
	for single in a:singles
		let parts = matchlist(a:line, single['reg'])
		if len(parts)
			call add(ret, [single, parts])
		endif
	endfor
	for multi in a:multis
		let parts = matchlist(a:line, multi['reg'])
		let matched = v:false
		for idx in a:000
			let matched = matched || strlen(parts[idx]) > 0
		endfor
		if matched
			call add(ret, [multi, parts])
		endif
	endfor
	return ret
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

"Search before for a line starting with multi['s']['val']
"Any lines containing multi['e']['val'] will end searching.
"0 if not found.  Otherwise the line number.
"Assume lineno does not contain the start. and search before
"it.
function! jhsiaoutil#MultiStart(lineno, multi, ...)
	if a:0
		let maxdif = a:1
	else
		let maxdif = 1000
	endif
	let check = a:lineno-1
	let lastline = max([1, check - maxdif])
	while lastline <= check
		let parts = matchlist(getline(check), a:multi['any'])
		if len(parts)
			if strlen(parts[2])
				return 0
			elseif strlen(parts[1])
				return check
			endif
		endif
		let check -= 1
	endwhile
	return 0
endfunction

"Find end of multi-line comment.
"Assume current line is a comment
"but does not contain the end part.
function! jhsiaoutil#MultiEnd(lineno, multi, ...)
	if a:0
		let maxdif = a:1
	else
		let maxdif = 1000
	endif
	let check = a:lineno+1
	let end = min(line('$'), check+maxdif)
	let pat = printf('\V%s', a:multi['e']['val'])
	while check <= end
		if match(getline(check), pat) >= 0
			return check
		endif
		let check += 1
	endwhile
	return 0
endfunction

"return the index of the character starting at/covering column (0-index)
"intended for use with str of space/tabs
"return index
function! jhsiaoutil#FindColumn(text, target)
	let idx = 0
	let col = 0
	while strlen(a:text[idx]) && col < a:target
		let newcol = col + strdisplaywidth(a:text[idx], col)
		if newcol > a:target
			return [col, idx]
		endif
		let col = newcol
		let idx += 1
	endwhile
	return [col, idx]
endfunction
