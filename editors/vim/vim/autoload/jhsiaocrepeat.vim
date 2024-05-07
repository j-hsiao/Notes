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
"https://vi.stackexchange.com/questions/13862/using-a-no-op-key-in-insert-mode-cant-use-key-after-using-no-op-mapping
"As writen above, this will fail.  From reading, it seems on a timeout, vim
"will expand the longest complete mapping up to that point.  This might
"explain why in a prefix recursive mapping, a timeout will nearly instantly
"reach the recursion limit.  Adding some no-op prefix will seem to prevent
"this.  However, the no-op must not expand to nothing.  ie, using <Plug>MyNop;
"as prefix with *map <Plug>MyNop; <Nop> will still result in instantly
"hitting the recursion limit.
"
"Furthermore, returning '' in the mapping and not consuming the next key seems
"to have a strange outcome where the next key does not get remapped.  However,
"if consuming it via getchar() and then returning the result, it will
"ex. if <C-K>/ is the target insert mode lhs, <C-K>/<C-K>/ will result in
"triggering the mapping once and then the non-mapped <C-K> followed by a /.
"Using getchar() to consume the <C-K> and then returning the result will
"result in activating the mapping twice.
"
if get(g:, 'loaded_jhsiaocrepeat', 0)
	finish
endif
let g:loaded_jhsiaocrepeat = 1

"Return a nop key sequence
"Must have some kind of key sequence to prevent recursive mapping
"from breaking down due to timeout.
if "\<Ignore>" == "<Ignore>"
	function! jhsiaocrepeat#Nop()
		let curmode = mode()
		if curmode == 'i'
			return "\<C-R>=''\<CR>"
		elseif curmode == 'n'
			return ":\<Esc>"
		else
			throw 'nop unsupported for mode "' . curmode . '"'
		endif
	endfunction
else
	function! jhsiaocrepeat#Nop()
		return "\<Ignore>"
	endfunction
endif

"Get the next keypress as a string.
function! jhsiaocrepeat#NextCharStr()
	let thing = getchar()
	if type(thing) == v:t_number
		return nr2char(thing)
	else
		return thing
	endif
endfunction

"Repeatedly wait for another key via an ambiguous mapping.
"ambigname: the name of the ambiguous mapping without the
"preceding <Plug>
function! jhsiaocrepeat#AmbiguousRepeat(ambigname)
	if getchar(1)
		let val = getchar()
		if type(val) == v:t_number
			let val = nr2char(val)
		endif
		"Strange behavior:
		"feedkeys and return have different outcomes.
		"1. Using return, the returned key will be interpreted as part
		"of a mapping.  (consecutive mappings activate correctly)
		"BUT: it has a very strange interaction with <C-[>. <Esc> does
		"not have this issue.  Typing <C-[> right after a mapping that
		"returns <C-[> seems to cause 5 undo commands.  Using
		"feedkeys(val, 'mti') seems to stop the undo commands, but
		"then the next keys are not interpreted as part of a mapping.
		"(even though using m flag so it should be mapped...)
		if (val == "\<C-[>")
			call feedkeys("\<Esc>", 'mti')
			return ''
		endif
		return val
	else
		let curmode = mode()
		if curmode == 'i'
			return printf("\<C-R>=''\<CR>\<Plug>%s", a:ambigname)
		elseif curmode == 'n'
			return printf(":\<Esc>\<Plug>%s", a:ambigname)
		else
			throw printf('ambiguous repeat not supported for mode "%s"', curmode)
		endif
	endif
endfunction

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


"Return a list of mapping commands that can be executed to create
"the desired repeatable mapping.
"Mappings should have <special> or < not in cpoptions
"cmd: map command
"	ex. 'imap <flag1> <flag2> lhs rhs'
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
	let repname = printf('jhsiaocrepeatAmbigufy%s%s;',
		\ mapinfo['mode'], substitute(mapinfo['lhs'], '<', '<lt>', 'g'))
	let mappings = []
	"Modified base mapping
	let rawcmd = printf(
		\ '%s %s <Plug>%sraw %s',
		\ mapinfo['mpcmd'], join(mapinfo['opts'], ' '),
		\ repname, join(mapinfo['rhs'], ' '))
	call add(mappings, rawcmd)

	let basecmd = printf(
		\ '%s <special> %s <Plug>%sraw<Plug>%s',
		\ substitute(mapinfo['mpcmd'], 'nore', '', ''),
		\ mapinfo['lhs'], repname, repname)
	call add(mappings, basecmd)

	"Repeat mapping
	if mapinfo['mode'] == 'v'
		let rhs = join(mapinfo['rhs'], '')
		if len(mapinfo['rhs']) && rhs[:4] == ':call'
			let repeatmap = printf(
				\ "%smap <special> <Plug>%s%s :'<,'>%s",
				\ after, repname, a:repkey, rhs[1:])
		else
			let repeatmap = printf(
				\ '%smap <special> <Plug>%s%s `<lt><Esc>v`>%s',
				\ after, repname, a:repkey, mapinfo['lhs'])
		endif
	else
		let repeatmap = printf(
			\ '%smap <special> <Plug>%s%s %s',
			\ after, repname, a:repkey, mapinfo['lhs'])
	endif
	call add(mappings, repeatmap)
	"Wait mapping
	let ambigmap = printf(
		\ '%smap <expr> <special> <Plug>%s jhsiaocrepeat#AmbiguousRepeat("%s")',
		\ after, repname, repname)
	call add(mappings, ambigmap)
	return join(mappings, '|')
endfunction
