:hi SpecialKey term=bold ctermfg=81 guifg=Cyan
:hi link EndOfBuffer NonText
:hi NonText term=bold ctermfg=12 gui=bold guifg=Blue
:hi Directory term=bold ctermfg=159 guifg=Cyan
:hi ErrorMsg term=standout ctermfg=15 ctermbg=1 guifg=White guibg=Red
:hi IncSearch term=reverse cterm=reverse gui=reverse
:hi Search term=reverse ctermfg=0 ctermbg=11 guifg=Black guibg=Yellow
:hi link CurSearch Search
:hi MoreMsg term=bold ctermfg=121 gui=bold guifg=SeaGreen
:hi ModeMsg term=bold cterm=bold gui=bold
:hi LineNr term=underline ctermfg=11 guifg=Yellow
:hi LineNrAbove NONE
:hi LineNrBelow NONE
:hi CursorLineNr term=bold cterm=underline ctermfg=11 gui=bold guifg=Yellow
:hi link CursorLineSign SignColumn
:hi link CursorLineFold FoldColumn
:hi Question term=standout ctermfg=121 gui=bold guifg=Green
:hi StatusLine term=bold,reverse cterm=bold,reverse gui=bold,reverse
:hi StatusLineNC term=reverse cterm=reverse gui=reverse
:hi VertSplit term=reverse cterm=reverse gui=reverse
:hi Title term=bold ctermfg=225 gui=bold guifg=Magenta
:hi Visual ctermfg=0 ctermbg=248 guifg=LightGrey guibg=#575757
:hi VisualNOS NONE
:hi WarningMsg term=standout ctermfg=224 guifg=Red
:hi WildMenu term=standout ctermfg=0 ctermbg=11 guifg=Black guibg=Yellow
:hi Folded term=standout ctermfg=14 ctermbg=242 guifg=Cyan guibg=DarkGrey
:hi FoldColumn term=standout ctermfg=14 ctermbg=242 guifg=Cyan guibg=Grey
:hi DiffAdd term=bold ctermbg=4 guibg=DarkBlue
:hi DiffChange term=bold ctermbg=5 guibg=DarkMagenta
:hi DiffDelete term=bold ctermfg=12 ctermbg=6 gui=bold guifg=Blue guibg=DarkCyan
:hi DiffText term=reverse cterm=bold ctermbg=9 gui=bold guibg=Red
:hi link DiffTextAdd DiffText
:hi SignColumn term=standout ctermfg=14 ctermbg=242 guifg=Cyan guibg=Grey
:hi Conceal ctermfg=7 ctermbg=242 guifg=LightGrey guibg=DarkGrey
:hi SpellBad term=reverse ctermbg=9 gui=undercurl guisp=Red
:hi SpellCap term=reverse ctermbg=12 gui=undercurl guisp=Blue
:hi SpellRare term=reverse ctermbg=13 gui=undercurl guisp=Magenta
:hi SpellLocal term=underline ctermbg=14 gui=undercurl guisp=Cyan
:hi Pmenu ctermfg=0 ctermbg=13 guibg=Magenta
:hi PmenuSel ctermfg=242 ctermbg=0 guibg=DarkGrey
:hi link PmenuMatch Pmenu
:hi link PmenuMatchSel PmenuSel
:hi link PmenuKind Pmenu
:hi link PmenuKindSel PmenuSel
:hi link PmenuExtra Pmenu
:hi link PmenuExtraSel PmenuSel
:hi PmenuSbar ctermbg=248 guibg=Grey
:hi PmenuThumb ctermbg=15 guibg=White
:hi link PmenuBorder Pmenu
:hi PmenuShadow ctermfg=242 ctermbg=0 guifg=DarkGrey guibg=Black
:hi TabLine term=underline cterm=underline ctermfg=15 ctermbg=242 gui=underline guibg=DarkGrey
:hi TabLineSel term=bold cterm=bold gui=bold
:hi TabLineFill term=reverse cterm=reverse gui=reverse
:hi CursorColumn term=reverse ctermbg=242 guibg=Grey40
:hi CursorLine term=underline cterm=underline guibg=Grey40
:hi ColorColumn term=reverse ctermbg=1 guibg=DarkRed
:hi link QuickFixLine Search
:hi StatusLineTerm term=bold,reverse cterm=bold ctermfg=0 ctermbg=121 gui=bold guifg=bg guibg=LightGreen
:hi StatusLineTermNC term=reverse ctermfg=0 ctermbg=121 guifg=bg guibg=LightGreen
:hi MsgArea NONE
:hi ComplMatchIns NONE
:hi link TabPanel TabLine
:hi link TabPanelSel TabLineSel
:hi link TabPanelFill TabLineFill
:hi link PreInsert Added
:hi link PopupSelected PmenuSel
:hi link MessageWindow WarningMsg
:hi link PopupNotification WarningMsg
:hi Added ctermfg=10 guifg=LimeGreen
:hi Normal NONE
:hi MatchParen term=reverse ctermbg=6 guibg=DarkCyan
:hi ToolbarLine term=underline ctermbg=242 guibg=Grey50
:hi ToolbarButton cterm=bold ctermfg=0 ctermbg=7 gui=bold guifg=Black guibg=LightGrey
:hi Comment term=bold ctermfg=14 guifg=#80a0ff
:hi Constant term=underline ctermfg=13 guifg=#ffa0a0
:hi Special term=bold ctermfg=224 guifg=Orange
:hi Identifier term=underline cterm=bold ctermfg=14 guifg=#40ffff
:hi Statement term=bold ctermfg=11 gui=bold guifg=#ffff60
:hi PreProc term=underline ctermfg=81 guifg=#ff80ff
:hi Type term=underline ctermfg=121 gui=bold guifg=#60ff60
:hi Underlined term=underline cterm=underline ctermfg=81 gui=underline guifg=#80a0ff
:hi Ignore ctermfg=0 guifg=bg
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
