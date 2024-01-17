"Functions for creating mappings with a kind of repeat mode.
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

let s:timeout_cache = []

"Save timeout and enter no-timeout mode.
function! s:SaveTimeouts()
	let s:timeout_cache = [&l:to, &l:ttimeout]
	setl noto nottimeout
	return ''
endfunction

imap <expr> <Plug>crepeatSaveTimeouts; <SID>SaveTimeouts()
nmap <expr> <Plug>crepeatSaveTimeouts; <SID>SaveTimeouts()
vmap <expr> <Plug>crepeatSaveTimeouts; <SID>SaveTimeouts()

"Restore timeout mode.
"repchar: bool, jjjkjk
function! s:RestoreTimeouts(...)
	let cmd = ['setl']
	if s:timeout_cache[0]
		call add(cmd, 'to')
	endif
	if s:timeout_cache[1]
		call add(cmd, 'ttimeout')
	endif
	let s:timeout_cache = []
	if len(cmd) > 1
		execute join(cmd, ' ')
	endif
	if a:0
		return a:1
	else
		return ''
	endif
endfunction

imap <expr> <Plug>crepeatRestoreTimeouts; <SID>RestoreTimeouts()
nmap <expr> <Plug>crepeatRestoreTimeouts; <SID>RestoreTimeouts()
vmap <expr> <Plug>crepeatRestoreTimeouts; <SID>RestoreTimeouts()


"Return a list of mapping commands that can be executed to create
"the desired repeatable mapping.
"
"cmd: map command
"lhs: lhs of command
"rhs: rhs of command
"key: key to use for repeat
function! crepeat#CharRepeatedCmds(cmd, lhs, rhs, key, ...)
	if isexpr
		let repeatlhs = '<Plug>' . a:lhs . ';'
		let commands = [
			\ a:cmd . a:lhs . a:rhs . "<Plug>crepeatSaveTimeouts;" . repeatlhs,
			\ a:cmd . repeatlhs . "<Plug>crepeatRestoreTimeouts;"
			\ a:cmd . repeatlhs . a:key . a:rhs . repeatlhs
		\ ]

		if a:key != '<Esc>'
			call add(commands, a:cmd . repeatlhs . "<Esc>" .  "<Plug>crepeatRestoreTimeouts;<Esc>")
		endif
	else
	endif


endfunction
