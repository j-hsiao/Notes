"Add a mapping if it exists else create new mapping.
function jhsiaoextendmap#ExtendMap(k, mode, extra, before)
	let dct = maparg(a:k, a:mode, v:false, v:true)
	if len(dct)
		let mpcmd = a:mode
		if dct['noremap']
			let mpcmd = mpcmd . 'nore'
		endif
		if get(dct, 'script', 0)
			echo 'Warning, <script> mapping being replicated in a different script.'
		endif
		let mpcmd = mpcmd . 'map '
		let extra = a:extra
		if dct['expr']
			let mpcmd = mpcmd . '<expr> '
			if a:before
				let extra = '"' . escape(a:extra, '"<\') . '" . '
			else
				let extra = ' . "' . escape(a:extra, '"<\') . '"'
			endif
		endif
		if dct['silent']
			let mpcmd = mpcmd . '<silent> '
		endif
		let rhs = substitute(dct['rhs'], '<sid>', '<SNR>' . dct['sid'] . '_', 'g')

		if a:before
			return mpcmd . dct['lhs'] . ' ' . extra . rhs
		else
			return mpcmd . dct['lhs'] . ' ' . rhs . extra
		endif
	else
		echo a:mode . 'noremap ' . a:k . ' ' . extra
		return a:mode . 'noremap ' . a:k . ' ' . extra
	endif
endfunction
