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

for cmd in ['noremap', 'noremap!', 'tnoremap', 'lnoremap']
	execute cmd . ' <Plug>jhsiaocrepeatNop; <Nop>'
endfor
map <Plug>jhsiaocrepeatNop; <Nop>

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
			if item[:3] == 'nore' || item[:2] == 'map'
				let ret['mode'] = ''
			else
				let ret['mode'] = item[0]
			endif
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

"Get the next keypress as a string.
function! jhsiaocrepeat#NextCharStr()
	let thing = getchar()
	if type(thing) == v:t_number
		return nr2char(thing)
	else
		return thing
	endif
endfunction

"Return a list of mapping commands that can be executed to create
"the desired repeatable mapping.
"Mappings should have <special> or < not in cpoptions
"cmd: map command
"repkey: key to press to repeat the mapping.
"extra arg:
"	ending mode, mostly for visual mode which may end in normal mode.
function! jhsiaocrepeat#CharRepeatedCmds(cmd, repkey, ...)
	let mapinfo = s:ParseMapCommand(a:cmd)
	if !get(mapinfo, '<special>', v:false) && match(&l:cpoptions, '<') >= 0
		echom 'Warning: "," in cpoptions but <special> not specified in jhsiaocrepeat#CharRepeatedCmds cmd argument.'
	endif
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
	else
		let basecmd = a:cmd . repname
	endif
	call add(mappings, basecmd)
	"Repeat mapping
	if mapinfo['mode'] == 'v'
		let repeatmap = printf(
			\ '%smap <special> %s%s `<lt><Esc>v`>%s',
			\ after, repname, a:repkey, mapinfo['lhs'])
	else
		let repeatmap = printf(
			\ '%smap <special> %s%s %s',
			\ after, repname, a:repkey, mapinfo['lhs'])
	endif
	call add(mappings, repeatmap)
	"Wait mapping
	let ambigmap = printf(
		\ '%smap <expr> <special> %s getchar(1) == 0 ? "%s%s" : jhsiaocrepeat#NextCharStr()',
		\ after, repname, '<Plug>jhsiaocrepeatNop;', repname)
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
