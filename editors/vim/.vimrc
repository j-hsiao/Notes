"summary of keybindings
"<C-K>  do something
"  ?        ask[?] bindings
"  c        toggle [c]olumn ruler stl
"  n        toggle [n]umbering
"  r        toggle [r]elative numbering
"  l        toggle [l]ist
"  b        scratch [b]uffer
"  )        toggle auto-close mappings (pair ([{ with closing )]})
"  <Tab>    toggle expandtab
"  p        toggle paste

"<C-K><C-K> set an option to numeric value
"  >        [shift]width
"  <Tab>    [tab]stop
"  <S-Tab>  [s]oft [tab]stop

"<-[><-[>   stop highlighting search
"<S-Tab>    literal tab character.
"<Tab>      spaces always
"<C-H>      delete width of spaces or do 1 bs.
"           (<S-BS> does not register on some cygwins...)
"<C-D>,<C-T>    shift and respect space alignment
"   >>, <<
"<C-K>i     move tabs in (mixed) leading whitespace to beginning
"<C-K>I     move tabs in (mixed) leading whitespace to end
"<C-K><C-K>i    <C-K>i on last selection
"<C-K><C-K>I    <C-K>I on last selection
"<C-K>a     realign block (same or more indent)
"           match previous lower-level indentation and then convert
"           the rest to spaces
"<C-K>s     select block (same or more indent)
"<C-.>      right shift last visual selection
"<C-,>      left shift last visual selection

syntax on
filetype plugin on
"basic options
nnoremap <C-K>? :nnoremap <lt>C-K><CR>
set nowrap number relativenumber ruler incsearch autoindent copyindent preserveindent
	\ ignorecase smartcase hlsearch
	\ hidden belloff=all scrolloff=0 list
	\ formatoptions+=roj
	\ listchars=eol:$,tab:.\ ,trail:_
	\ wmnu wim=list:longest,list:full wic
	\ ls=2 stl=%<%n\ %f\ %h%m%r%=%l(%p%%),%c%V

"Note: one maybe large benefit of ftplugin over autocmd is that
"the ftplugin has its own file-type identification that can be
"updated if vim is updated.  With autocmd, you must update them
"yourself.
" augroup Myft
" 	autocmd! Myft
" 	autocmd Myft bufnewfile,bufread *.py setlocal sts=4 sw=4 expandtab
" 	autocmd Myft bufnewfile,bufread *.c,*.h,*.cpp,*.hpp setlocal sts=2 sw=2 noexpandtab
" 	autocmd Myft bufnewfile,bufread *.cmake,CMakeLists.txt,*.cmake.in setlocal ts=4 sts=0 sw=4
" 	autocmd Myft bufnewfile,bufread *.sh setlocal ts=4 sts=0 sw=4 noexpandtab
" 	autocmd Myft bufnewfile,bufread *.txt setlocal sw=2 sts=4 ts=4
" augroup END
