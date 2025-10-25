:hi SpecialKey term=bold ctermfg=4 guifg=Blue
:hi link EndOfBuffer NonText
:hi NonText term=bold ctermfg=12 gui=bold guifg=Blue
:hi Directory term=bold ctermfg=4 guifg=Blue
:hi ErrorMsg term=standout ctermfg=15 ctermbg=1 guifg=White guibg=Red
:hi IncSearch term=reverse cterm=reverse gui=reverse
:hi Search term=reverse ctermbg=11 guibg=Yellow
:hi link CurSearch Search
:hi MoreMsg term=bold ctermfg=2 gui=bold guifg=SeaGreen
:hi ModeMsg term=bold cterm=bold gui=bold
:hi LineNr term=underline ctermfg=130 guifg=Brown
:hi LineNrAbove NONE
:hi LineNrBelow NONE
:hi CursorLineNr term=bold cterm=underline ctermfg=130 gui=bold guifg=Brown
:hi link CursorLineSign SignColumn
:hi link CursorLineFold FoldColumn
:hi Question term=standout ctermfg=2 gui=bold guifg=SeaGreen
:hi StatusLine term=bold,reverse cterm=bold,reverse gui=bold,reverse
:hi StatusLineNC term=reverse cterm=reverse gui=reverse
:hi VertSplit term=reverse cterm=reverse gui=reverse
:hi Title term=bold ctermfg=5 gui=bold guifg=Magenta
:hi Visual ctermfg=0 ctermbg=248 guifg=Black guibg=LightGrey
:hi VisualNOS NONE
:hi WarningMsg term=standout ctermfg=1 guifg=Red
:hi WildMenu term=standout ctermfg=0 ctermbg=11 guifg=Black guibg=Yellow
:hi Folded term=standout ctermfg=4 ctermbg=248 guifg=DarkBlue guibg=LightGrey
:hi FoldColumn term=standout ctermfg=4 ctermbg=248 guifg=DarkBlue guibg=Grey
:hi DiffAdd term=bold ctermbg=81 guibg=LightBlue
:hi DiffChange term=bold ctermbg=225 guibg=LightMagenta
:hi DiffDelete term=bold ctermfg=12 ctermbg=159 gui=bold guifg=Blue guibg=LightCyan
:hi DiffText term=reverse cterm=bold ctermbg=9 gui=bold guibg=Red
:hi link DiffTextAdd DiffText
:hi SignColumn term=standout ctermfg=4 ctermbg=248 guifg=DarkBlue guibg=Grey
:hi Conceal ctermfg=7 ctermbg=242 guifg=LightGrey guibg=DarkGrey
:hi SpellBad term=reverse ctermbg=224 gui=undercurl guisp=Red
:hi SpellCap term=reverse ctermbg=81 gui=undercurl guisp=Blue
:hi SpellRare term=reverse ctermbg=225 gui=undercurl guisp=Magenta
:hi SpellLocal term=underline ctermbg=14 gui=undercurl guisp=DarkCyan
:hi Pmenu ctermfg=0 ctermbg=225 guibg=LightMagenta
:hi PmenuSel ctermfg=0 ctermbg=7 guibg=Grey
:hi link PmenuMatch Pmenu
:hi link PmenuMatchSel PmenuSel
:hi link PmenuKind Pmenu
:hi link PmenuKindSel PmenuSel
:hi link PmenuExtra Pmenu
:hi link PmenuExtraSel PmenuSel
:hi PmenuSbar ctermbg=248 guibg=Grey
:hi PmenuThumb ctermbg=0 guibg=Black
:hi link PmenuBorder Pmenu
:hi PmenuShadow ctermfg=242 ctermbg=0 guifg=DarkGrey guibg=Black
:hi TabLine term=underline cterm=underline ctermfg=0 ctermbg=7 gui=underline guibg=LightGrey
:hi TabLineSel term=bold cterm=bold gui=bold
:hi TabLineFill term=reverse cterm=reverse gui=reverse
:hi CursorColumn term=reverse ctermbg=7 guibg=Grey90
:hi CursorLine term=underline cterm=underline guibg=Grey90
:hi ColorColumn term=reverse ctermbg=224 guibg=LightRed
:hi link QuickFixLine Search
:hi StatusLineTerm term=bold,reverse cterm=bold ctermfg=15 ctermbg=2 gui=bold guifg=bg guibg=DarkGreen
:hi StatusLineTermNC term=reverse ctermfg=15 ctermbg=2 guifg=bg guibg=DarkGreen
:hi MsgArea NONE
:hi ComplMatchIns NONE
:hi link TabPanel TabLine
:hi link TabPanelSel TabLineSel
:hi link TabPanelFill TabLineFill
:hi link PreInsert Added
:hi link PopupSelected PmenuSel
:hi link MessageWindow WarningMsg
:hi link PopupNotification WarningMsg
:hi Added ctermfg=2 guifg=SeaGreen
:hi Normal NONE
:hi MatchParen term=reverse ctermbg=14 guibg=Cyan
:hi ToolbarLine term=underline ctermbg=7 guibg=LightGrey
:hi ToolbarButton cterm=bold ctermfg=15 ctermbg=242 gui=bold guifg=White guibg=Grey40
:hi Comment term=bold ctermfg=4 guifg=Blue
:hi Constant term=underline ctermfg=1 guifg=Magenta
:hi Special term=bold ctermfg=5 guifg=#6a5acd
:hi Identifier term=underline ctermfg=6 guifg=DarkCyan
:hi Statement term=bold ctermfg=130 gui=bold guifg=Brown
:hi PreProc term=underline ctermfg=5 guifg=#6a0dad
:hi Type term=underline ctermfg=2 gui=bold guifg=SeaGreen
:hi Underlined term=underline cterm=underline ctermfg=5 gui=underline guifg=SlateBlue
:hi Ignore ctermfg=15 guifg=bg
:hi Changed ctermfg=12 guifg=DodgerBlue
:hi Removed ctermfg=9 guifg=Red
:hi Error term=reverse ctermfg=15 ctermbg=9 guifg=White guibg=Red
:hi Todo term=standout ctermfg=0 ctermbg=11 guifg=Blue guibg=Yellow
:hi Bold term=bold cterm=bold gui=bold
:hi Italic term=italic cterm=italic gui=italic
:hi BoldItalic term=bold,italic cterm=bold,italic gui=bold,italic
:hi link String Constant
:hi link Character Constant
:hi link Number Constant
:hi link Boolean Constant
:hi link Float Number
:hi link Function Identifier
:hi link Conditional Statement
:hi link Repeat Statement
:hi link Label Statement
:hi link Operator Statement
:hi link Keyword Statement
:hi link Exception Statement
:hi link Include PreProc
:hi link Define PreProc
:hi link Macro PreProc
:hi link PreCondit PreProc
:hi link StorageClass Type
:hi link Structure Type
:hi link Typedef Type
:hi link Tag Special
:hi link SpecialChar Special
:hi link Delimiter Special
:hi link SpecialComment Special
:hi link Debug Special
