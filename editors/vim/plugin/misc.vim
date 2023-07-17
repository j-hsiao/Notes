"Miscellaneous mappings and settings
"These usually begin with C-K

"basic options
nnoremap <C-K>? :nnoremap <lt>C-K><CR>

"file ui
set wmnu wim=list:longest,list:full wic

"listchars
set listchars=eol:$,tab:.\ ,trail:_
"toggle display lcs
nnoremap <C-K>l :setlocal list! list?<CR>

"toggle paste mode
nnoremap <C-K>p :setlocal paste! paste?<CR>

"status line
set ls=2 stl=%<%n\ %f\ %h%m%r%=%l(%p%%),%c%V\ %P

"counterpart to <C-H>
inoremap <silent> <C-L> <Del>

"toggle row numbering
nnoremap <C-K>n :setlocal number! number?<CR>
nnoremap <C-K>r :setlocal relativenumber! relativenumber?<CR>

"cancel search highlights
nnoremap <silent> <C-[><C-[> :nohl<CR>

"scratch buffer
nnoremap <C-K>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>

"------------------------------
"shortcut tab/indent settings
"(number)C-K C-K >|S-Tab|Tab
"C-K Tab: toggle et
"------------------------------
"Shortcut 
"shiftwidth
nnoremap <silent> <C-K><C-K>> :<C-U>execute "setlocal sw" . (v:count == v:count1 ? "=" . v:count : "&")<CR>
"softtabstop
nnoremap <silent> <C-K><C-K><S-Tab> :<C-U>execute "setlocal sts" . (v:count == v:count1 ? "=" . v:count : "&")<CR>
"tabstop
nnoremap <silent> <C-K><C-K><Tab> :<C-U>execute "setlocal ts" . (v:count == v:count1 ? "=" . v:count : "&")<CR>
"expandtab
nnoremap <silent> <C-K><Tab> :setlocal expandtab! expandtab?<CR>

"Easier escape
inoremap ;l <Esc>

"Abbreviations
inorea <expr> --- repeat('-', 30)
inorea <expr> ___ repeat('_', 30)
inorea Inp Inputs<CR>======
inorea Outp Outputs<CR>=======
