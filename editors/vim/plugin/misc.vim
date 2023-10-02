"Miscellaneous mappings and settings
"These usually begin with C-K
"
"toggling common settings:
"  <C-K>
"       l: list
"       p: paste
"       n: number
"       r: relative number
"       tab: expandtab
"
"Setting common settings:
"  <C-K><C-K>
"       >: shiftwidth
"       shift+tab: softtabstop
"       tab: tabstop
"others
"  <C-K>
"       b: Change current frame to new scratch buffer
"       k: original <C-K>
"       -: 30 - separator
"       =: 30 = separator
"       _: 30 _ separator
"
"Abbreviations:
"  Inp:  Inputs header
"  Outp: Outputs header

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
nnoremap <silent> <C-K><C-K>> :<C-U>execute "setlocal sw" . (v:count == v:count1 ? "=" . v:count : "&") . " sw?"<CR>
"softtabstop
nnoremap <silent> <C-K><C-K><S-Tab> :<C-U>execute "setlocal sts" . (v:count == v:count1 ? "=" . v:count : "&") . " sts?"<CR>
"tabstop
nnoremap <silent> <C-K><C-K><Tab> :<C-U>execute "setlocal ts" . (v:count == v:count1 ? "=" . v:count : "&") . " ts?"<CR>
"expandtab
nnoremap <silent> <C-K><Tab> :setlocal expandtab! expandtab?<CR>

"Easier escape
inoremap ;l <Esc>

"Preserve a mapping to original <C-K>
inoremap <C-K>k <C-K>

"Sectioning
inoremap <expr> <C-K>- repeat('-', 30)
inoremap <expr> <C-K>= repeat('=', 30)
inoremap <expr> <C-K>_ repeat('_', 30)

inorea Inp Inputs<CR>======
inorea Outp Outputs<CR>=======
