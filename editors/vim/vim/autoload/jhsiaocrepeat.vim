"Functions for creating mappings that can be repeated with a given key.
"
"Use mapping ambiguity to see if the next key is the repeat key
"or some other key.
"
"Append an ambiguous mapping to the end of the desired mapping.
"
"original:
"*map lhs rhs
"
"result:
"*map lhs rhs<Plug>Ambiglhs;
"*map <expr> <Plug>Ambiglhs; getchar(1) == 0 ? <Plug>Ambiglhs; : ''
"*map <Plug>ambiglhs;key -> lhs
"
"As writen above, this will fail because of some strange
"recursive interaction that does not match :h recursive_mapping.
"According to recursive_mapping, the <Plug>Ambiglhs; should not be
"mapped again and so should fail.  Instead, it just causes instant
"infinite recursion until the max recursion limit and errors out.
"Something else is needed in front of it to avoid this recursive
"behavior.  <Ignore> is used if available.  <Nop> does not work.
"If anything comes after it, then 5 chars <Nop> are added.

if get(g:, 'loaded_jhsiaocrepeat', 0)
	finish
endif
let g:loaded_jhsiaocrepeat = 1

if strlen("\<Ignore>") == strlen('<Ignore>')
	let s:nop = 'a<BS>'
else
	let s:nop = '<Ignore>'
endif

let s:special = [
	\ '<expr>', '<buffer>', '<nowait>', '<silent>',
	\ '<special>', '<script>', '<unique>']

"Parse a map command.  Any spaces intended as part of rhs or lhs should
"use <Space> notation instead.
function! s:ParseMapCommand(cmd)
	let ret = {'opts': [], 'rhs': []}
	let stage = 'start'
	for item in split(a:cmd, ' ')
		if stage == 'start'
			let ret['mpcmd'] = item
			let ret['mode'] = item[:0]
			let stage = 'special'
		elseif stage == 'special'
			if index(s:special, item) >= 0
				call add(ret['opts'], item)
				let ret[item] = v:true
			else
				let ret['lhs'] = item
				let stage = 'rhs'
			endif
		else
			call add(ret['rhs'], item)
		endif
	endfor
	return ret
endfunction

"Return a list of mapping commands that can be executed to create
"the desired repeatable mapping.
"
"cmd: map command
"repkey: key to press to repeat the mapping.
"extra arg:
"	ending mode, mostly for visual mode which may end in normal mode.
function! jhsiaocrepeat#CharRepeatedCmds(cmd, repkey, ...)
	let mapinfo = s:ParseMapCommand(a:cmd)
	let after = mapinfo['mode']
	if a:0
		let after = a:1
	endif
	let repname = '<Plug>jhsiaocrepeatAmbigufy'
		\ . mapinfo['mode'] . mapinfo['lhs'] . ';'
	let mappings = []
	"Modified base mapping
	if get(mapinfo, '<expr>', v:false)
		let basecmd = printf(
			\ '%s %s %s (%s) . "%s"',
			\ mapinfo['mpcmd'], join(mapinfo['opts'], ' '),
			\ mapinfo['lhs'], mapinfo['rhs'], repname)
		call add(mappings, basecmd)
	else
		call add(mappings, a:cmd . repname)
	endif
	"Repeat mapping
	if mapinfo['mode'] == 'v'
		let repeatmap = printf(
			\ '%smap <special> %s%s `<lt>v`>%s',
			\ after, repname, a:repkey, mapinfo['lhs'])
		call add(mappings, repeatmap)
	else
		let repeatmap = printf(
			\ '%smap <special> %s%s %s',
			\ after, repname, a:repkey, mapinfo['lhs'])
		call add(mappings, repeatmap)
	endif
	"Wait mapping
	let ambigmap = printf(
		\ '%smap <expr> <special> %s getchar(1) == 0 ? "%s%s" : ""',
		\ after, repname, s:nop, repname)
	call add(mappings, ambigmap)

	"let parts = split(a:cmd, ' ')
	"let mpcmd = parts[0]
	"let idx = 1
	"let opts = []
	"let isexpr = 0
	"while idx < len(parts) && index(s:special, parts[idx]) >= 0
	"	call add(opts, parts[idx])
	"	if parts[idx] == s:special[0]
	"		let isexpr = 1
	"	endif
	"	let idx += 1
	"endwhile
	"let lhs = parts[idx]
	"let idx += 1
	"let rhs = join(parts[idx:], ' ')
	"let mpmode = mpcmd[:0]
	"let after = mpmode
	"if a:0
	"	let after = a:1
	"endif
	"let repname = '<Plug>jhsiaocrepeatAmbigufy' . mpmode . lhs . ';'
	"let mappings = []
	"if isexpr
	"	let basecmd = [mpcmd]
	"	call extend(basecmd, opts)
	"	call add(basecmd, lhs)
	"	call add(basecmd, '(' . rhs . ')' . ' . "' . repname . '"')
	"	call add(mappings, join(basecmd, ' '))
	"else
	"	call add(mappings, a:cmd . repname)
	"endif
	"if mpmode == 'v'
	"	call add(mappings, join([after . 'map <special>', repname . a:repkey, "'<lt>v'>" . lhs], ' '))
	"else
	"	call add(mappings, join([after . 'map <special>', repname . a:repkey, lhs], ' '))
	"endif
	"call add(
	"	\ mappings,
	"	\ join([
	"		\ after.'map <expr> <special>', repname,
	"		\ 'getchar(1) == 0 ? "' . s:nop . repname . '" : ""'], ' '))
	return join(mappings, '|')
endfunction
