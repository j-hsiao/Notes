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

"counterpart to <C-H>
inoremap <silent> <C-L> <Del>

"cancel search highlights
nnoremap <silent> <C-[><C-[> :nohl<CR>

"scratch buffer
nnoremap <C-K>b :enew<CR>:setlocal buftype=nofile bufhidden=hide noswapfile<CR>

"Easier escape
inoremap ;l <Esc>

"Preserve a mapping to original <C-K>
inoremap <C-K>k <C-K>

"Sectioning
inoremap <expr> <C-K>- repeat('-', 30)
inoremap <expr> <C-K>= repeat('=', 30)
inoremap <expr> <C-K>_ repeat('_', 30)

"<C-O> that insert text but end back up in insert mode instead of
"normal mode
inoremap <C-K><C-O> <C-O>:norm<Space>
inoremap <C-K>o <C-O>:norm<Space>

inorea Inp Inputs<CR>======
inorea Outp Outputs<CR>=======
