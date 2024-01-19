"Functions for creating mappings that can be repeated with a given key.
"
"This is implemented using mapping ambiguity which causes vim to pause
"and wait for another key.  If the next key matches, then do action
"and then back to ambiguous.
"
"Multiple bindings are required to achieve the desired effect.
"1. The raw binding for activating once and then enter ambiguity resolution.
"2. The binding for repeat with key: redo the action.
"3. The binding for repeat without key: make withkey ambiguous causing pause.
"4. optional binding with <Esc>.  This is because noto will cause <Esc>
"   to pause.  Note: noto is used to cause the vim ambiguity to hang until
"   some key is pressed effectively waiting to see if the repeat key was
"   pressed.  without using getchar() which causes the cursor to move to
"   cmdline.  This allows retaining a visual indication of the current
"   location of the cursor.
"


"Note, prefix recursive ambiguous mappings will result in no ambiguity
"resolution.  as a result, ambiguous action must be broken by something.
if strlen("\<Ignore>") == strlen('<Ignore>')
	let s:nop = 'a<BS>'
else
	let s:nop = '<Ignore>'
endif

let s:special = ['<expr>', '<buffer>', '<nowait>', '<silent>', '<special>', '<script>', '<unique>']

"Return a list of mapping commands that can be executed to create
"the desired repeatable mapping.
"
"cmd: map command
"lhs: lhs of command
"rhs: rhs of command
"key: key to use for repeat
function! crepeat#CharRepeatedCmds(cmd, repkey)
	let parts = split(a:cmd, ' ')
	let mpcmd = parts[0]
	let idx = 1
	let opts = []
	let isexpr = 0
	while idx < len(parts) && index(s:special, parts[idx]) >= 0
		call add(opts, parts[idx])
		if parts[idx] == s:special[0]
			let isexpr = 1
		endif
		let idx += 1
	endwhile
	let lhs = parts[idx]
	let idx += 1
	let rhs = join(parts[idx:], ' ')
	let mpmode = mpcmd[:0]

	let repname = '<Plug>crepeatAmbigufy' . lhs . ';'
	let mappings = []
	if isexpr
		let basecmd = [mpcmd]
		call extend(basecmd, opts)
		call add(basecmd, lhs)
		call add(basecmd, '(' . rhs . ')' . ' . "' . repname . '"')
		call add(mappings, join(basecmd, ' '))
	else
		call add(mappings, a:cmd . repname)
	endif
	call add(mappings, join([mpmode . 'map <special>', repname . a:repkey, lhs], ' '))

	call add(
		\ mappings,
		\ join([
			\ mpmode.'map <expr> <special>', repname,
			\ 'getchar(1) == 0 ? "' . s:nop . repname . '" : ""'], ' '))
	return mappings
endfunction
