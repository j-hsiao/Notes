" Column-ruler stl
function! s:RulerSTL(...)
	"Return a string suitable for use as the status line that shows
	"the columns similar to nu.  Numbering starts at 1 and numbers
	"each sts or sw or ts, whichever is non-zero first.  If the max
	"column + indicator + space is larger than the interval, double
	"the interval until the column numbering can fit.
	"Optional arguments: delimiter per column, delimiter for curcol.
	let delim = a:0 ? a:1 : '|'
	let cdelim = a:0 > 1 ? a:2 : '^'
	let step = &l:sts ? &l:sts : &l:sw ? &l:sw : &l:ts
	let maxlen = winwidth(0)
	let midlen = len(max([col('$'), maxlen]) . '^ ')
	while step < midlen
		let step += step
	endwhile
	let cwinvpos = wincol()
	let cbufvpos = virtcol('.')
	let curcol = col('.')
	let curchar = getline('.')[curcol-1]
	"For tabs, the virtual column is the last column of the tab
	"rather than the beginning.  However, if list is set, then
	"the cursor is placed on the beginning of the tab rather than
	"the last column of the tab.  Correct the issue.
	if curchar == "\t" && &l:list
		" could be <space><Tab>
		" to get the tab start, need the end of the previous char
		" can't just take tab and subtract ts-1 because that would
		" give the space's col, not tab's col
		if curcol > 1
			call cursor(0, curcol-1)
			let cbufvpos = virtcol('.') + 1
			call cursor(0, curcol)
		else
			let cbufvpos -= &l:ts - 1
		endif
	endif
	let maxlen = winwidth(0)
	let mystl = []
	let mystl = repeat([' '], maxlen)
	let lcbegin = cbufvpos - cwinvpos
	let remainder = lcbegin % step
	if remainder < 0
		let remainder += step
	endif

	let idx = -remainder
	let lcbegin -= remainder
	let lcbegin += 1
	if idx < 0
		if lcbegin > 0
			let digits = split(delim . lcbegin, '\zs')
			let shown = len(digits) + idx
			if shown > 0
				let mystl[:idx + len(digits)-1] = digits[-shown:]
			endif
		endif
		let lcbegin += step
		let idx += step
	endif
	for idx in range(idx, maxlen-1, step)
		let digits = split(delim . lcbegin, '\zs')
		let space = min([maxlen - idx, len(digits)])-1
		let mystl[idx:idx+space] = digits[:space]
		let lcbegin += step
	endfor
	let digits = split(cdelim . cbufvpos, '\zs')
	let idx = cwinvpos - 1
	if maxlen - idx < len(digits)
		let [lidx, ridx] = [idx-len(digits), idx+1]
		let mystl[lidx+1:idx-1] = digits[1:]
		let mystl[idx] = cdelim
	else
		let [lidx, ridx] = [idx-1, idx+len(digits)]
		let mystl[idx:ridx-1] = digits
	endif
	while lidx >= 0 && mystl[lidx] != ' '
		let mystl[lidx] = ' '
		let lidx -= 1
	endwhile
	while ridx < maxlen && mystl[ridx] != ' '
		let mystl[ridx] = ' '
		let ridx += 1
	endwhile
	return join(mystl, '')
endfunction

function! CpOrigSTL()
	if ! exists('w:ColRuler_origstl') && &l:stl == '%!s:RulerSTL()'
		let w:ColRuler_origstl = getwinvar(winnr('#'), 'ColRuler_origstl')
	endif
endfunction
augroup CpOrigstlOnSplit
	au! CpOrigstlOnSplit
	au WinEnter * call CpOrigSTL()
augroup END

unlet! w:ColRuler_origstl
function! ColRuler()
	"Toggle using s:RulerSTL() for stl
	"The original stl line is saved as w:ColRuler_origstl
	if !exists('w:ColRuler_origstl') || &l:stl != '%!s:RulerSTL()'
		let w:ColRuler_origstl = &l:stl
		let &l:stl = '%!s:RulerSTL()'
	else
		let &l:stl = w:ColRuler_origstl
	endif
endfunction
nnoremap <silent> <C-K>c :call ColRuler()<CR>
