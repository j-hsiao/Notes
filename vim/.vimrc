syntax on
filetype plugin on
"file ui
set wmnu wim=list:longest,list:full wic
"status line
set ls=2 stl=%<%n\ %f\ %h%m%r%=%l,%c%V\ %P(%p%%)
"listchars
set listchars=eol:$,tab:.\ ,trail:.
nnoremap <C-K><C-L> :setlocal list! list?<CR>
"cancel search highlights
nnoremap <silent> <Esc><Esc> :nohl<CR>
"shiftwidth
nnoremap <silent> <C-K><C-K>> :<C-U>execute "setlocal sw" . (v:count == 0 ? "&" : "=" . v:count)<CR>
"softtabstop
nnoremap <silent> <C-K><C-K><S-Tab> :<C-U>execute "setlocal sts" . (v:count == 0 ? "&" : "=" . v:count)<CR>
"tabstop
nnoremap <silent> <C-K><C-K><Tab> :<C-U>execute "setlocal ts" . (v:count == 0 ? "&" : "=" . v:count)<CR>
"expandtab
nnoremap <silent> <C-K><Tab> :setlocal expandtab! expandtab?<CR>
"scratch buffer
nnoremap <C-K>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>
"basic options
set nowrap autoindent number
set ignorecase smartcase hidden hls bo=all scrolloff=0 list
set fo+=roj

aug Myft
	au! Myft
	au Myft bufnewfile,bufread *.py setlocal sts=4 sw=4 expandtab
	au Myft bufnewfile,bufread *.c,*.h,*.cpp,*.hpp setlocal sts=2 sw=2 noexpandtab
	au Myft bufnewfile,bufread *.cmake,CMakeLists.txt setlocal ts=4 sts=0 sw=4
	au Myft bufnewfile,bufread *.sh setlocal ts=4 sts=0 sw=4 noexpandtab
	au Myft bufnewfile,bufread *.txt setlocal sw=2 sts=4 ts=4
aug END

"auto-add and close ([{
inoremap ( ()<Esc>i
inoremap [ []<Esc>i
inoremap { {}<Esc>i
function IgnoreIfCloser(key)
	let curline = getline(".")
	let insexit = col("'^")
	if insexit > len(curline) || curline[insexit - 1] != a:key
		execute "norm! gi" . a:key
	endif
	let curline = getline(".")
	call cursor(line("."), insexit+1)
	if insexit+1 > len(curline)
		startinsert!
	else
		startinsert
	endif
endfunction
inoremap ) <Esc>:call IgnoreIfCloser(")")<CR>
inoremap ] <Esc>:call IgnoreIfCloser("]")<CR>
inoremap } <Esc>:call IgnoreIfCloser("}")<CR>
