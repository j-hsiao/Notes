if get(g:, 'loaded_jhsiaomapfallback', 0)
	finish
endif
let g:loaded_jhsiaomapfallback = 1

"Creating the map inside the function would result in the
"function being considered as created in this script instead
"of the calling script.
function jhsiaomapfallback#CreateFallback(name, k, mode)
	let dct = maparg(a:k, a:mode, v:false, v:true)
	if len(dct)
		if exists('*mapset')
			let dct['lhs'] = a:name
			execute "let dct['lhsraw'] = \"" . escape(a:name, '"<\') . '"'
			let dct['rhs'] = substitute(dct['rhs'], '<SID>', '<SNR>' . dct['sid'] . '_', 'g')
			return "call mapset('i', v:false, " . string(dct) . ')'
		else
			let mpcmd = a:mode
			if dct['noremap']
				let mpcmd = mpcmd . 'nore'
			endif
			if get(dct, 'script', 0)
				echo 'Warning, <script> mapping being replicated in a different script.'
			endif
			let mpcmd = mpcmd . 'map '
			if dct['expr']
				let mpcmd = mpcmd . '<expr> '
			endif
			if dct['silent']
				let mapcmd = mapcmd . '<silent> '
			endif
			let rhs = substitute(dct['rhs'], '<sid>', '<SNR>' . dct['sid'] . '_', 'g')
			return mpcmd . a:name . ' ' . rhs
		endif
	else
		" no prior mapping, just map to the key itself.
		return 'inoremap ' . a:name . ' ' . a:k
	endif
endfunction
