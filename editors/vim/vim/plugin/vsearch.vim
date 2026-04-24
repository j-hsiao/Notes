"Search the highlighted text

vnoremap <expr> <Plug>VsearchSearch_forward; vsearch#search('/', v:true)
vnoremap <expr> <Plug>VsearchSearch_forward_exact; vsearch#search('/', v:false)
vnoremap <expr> <Plug>VsearchSearch_backward; vsearch#search('?', v:true)
vnoremap <expr> <Plug>VsearchSearch_backward_exact; vsearch#search('?', v:false)
nnoremap <expr> <Plug>VsearchSearch_note_header; vsearch#notesearch()


if maparg("*", 'v') == ''
	vmap * <Plug>VsearchSearch_forward;
endif
if maparg("#", 'v') == ''
	vmap # <Plug>VsearchSearch_backward;
endif

if maparg("<Leader>*", 'v') == ''
	vmap <Leader>* <Plug>VsearchSearch_forward_exact;
endif
if maparg("<Leader>#", 'v') == ''
	vmap <Leader># <Plug>VsearchSearch_backward_exact;
endif


if maparg("<Leader><C-]>", 'n') == ''
	nmap <Leader><C-]> <Plug>VsearchSearch_note_header;
endif
