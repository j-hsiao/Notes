:hi SpecialKey term=bold ctermfg=81 guifg=Cyan
:hi link EndOfBuffer NonText
:hi NonText term=bold ctermfg=12 gui=bold guifg=Blue
:hi Directory term=bold ctermfg=159 guifg=Cyan
:hi ErrorMsg term=standout ctermfg=15 ctermbg=1 guifg=White guibg=Red
:hi IncSearch term=reverse cterm=reverse gui=reverse
:hi Search term=reverse ctermfg=0 ctermbg=11 guifg=Black guibg=Yellow
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
:hi Visual term=reverse ctermbg=242 guibg=DarkGrey
:hi VisualNOS NONE
:hi WarningMsg term=standout ctermfg=224 guifg=Red
:hi WildMenu term=standout ctermfg=0 ctermbg=11 guifg=Black guibg=Yellow
:hi Folded term=standout ctermfg=14 ctermbg=242 guifg=Cyan guibg=DarkGrey
:hi FoldColumn term=standout ctermfg=14 ctermbg=242 guifg=Cyan guibg=Grey
:hi DiffAdd term=bold ctermbg=4 guibg=DarkBlue
:hi DiffChange term=bold ctermbg=5 guibg=DarkMagenta
:hi DiffDelete term=bold ctermfg=12 ctermbg=6 gui=bold guifg=Blue guibg=DarkCyan
:hi DiffText term=reverse cterm=bold ctermbg=9 gui=bold guibg=Red
:hi SignColumn term=standout ctermfg=14 ctermbg=242 guifg=Cyan guibg=Grey
:hi Conceal ctermfg=7 ctermbg=242 guifg=LightGrey guibg=DarkGrey
:hi SpellBad term=reverse ctermbg=9 gui=undercurl guisp=Red
:hi SpellCap term=reverse ctermbg=12 gui=undercurl guisp=Blue
:hi SpellRare term=reverse ctermbg=13 gui=undercurl guisp=Magenta
:hi SpellLocal term=underline ctermbg=14 gui=undercurl guisp=Cyan
:hi Pmenu ctermfg=0 ctermbg=13 guibg=Magenta
:hi PmenuSel ctermfg=242 ctermbg=0 guibg=DarkGrey
:hi PmenuSbar ctermbg=248 guibg=Grey
:hi PmenuThumb ctermbg=15 guibg=White
:hi TabLine term=underline cterm=underline ctermfg=15 ctermbg=242 gui=underline guibg=DarkGrey
:hi TabLineSel term=bold cterm=bold gui=bold
:hi TabLineFill term=reverse cterm=reverse gui=reverse
:hi CursorColumn term=reverse ctermbg=242 guibg=Grey40
:hi CursorLine term=underline cterm=underline guibg=Grey40
:hi ColorColumn term=reverse ctermbg=1 guibg=DarkRed
:hi link QuickFixLine Search
:hi StatusLineTerm term=bold,reverse cterm=bold ctermfg=0 ctermbg=121 gui=bold guifg=bg guibg=LightGreen
:hi StatusLineTermNC term=reverse ctermfg=0 ctermbg=121 guifg=bg guibg=LightGreen
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
:hi Error term=reverse ctermfg=15 ctermbg=9 guifg=White guibg=Red
:hi Todo term=standout ctermfg=0 ctermbg=11 guifg=Blue guibg=Yellow
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
:hi link vimTodo Todo
:hi link vimCommand Statement
:hi vimStdPlugin NONE
:hi link vimOption PreProc
:hi link vimErrSetting vimError
:hi link vimAutoEvent Type
:hi link vimGroup Type
:hi link vimHLGroup vimGroup
:hi link vimFuncName Function
:hi vimGlobal NONE
:hi link vimSubst vimCommand
:hi link vimComment Comment
:hi link vim9Comment Comment
:hi link vimNumber Number
:hi link vimAddress vimMark
:hi link vimAutoCmd vimCommand
:hi vimEcho NONE
:hi vimIsCommand NONE
:hi vimExtCmd NONE
:hi vimFilter NONE
:hi link vimLet vimCommand
:hi link vimMap vimCommand
:hi link vimMark Number
:hi vimSet NONE
:hi link vimSyntax vimCommand
:hi vimUserCmd NONE
:hi vimCmdSep NONE
:hi link vimVar Identifier
:hi link vimFBVar vimVar
:hi link vimBehaveModel vimBehave
:hi link vimBehaveError vimError
:hi link vimBehave vimCommand
:hi link vimFTCmd vimCommand
:hi link vimFTOption vimSynType
:hi link vimFTError vimError
:hi vimFiletype NONE
:hi vimAugroup NONE
:hi vimExecute NONE
:hi link vimNotFunc vimCommand
:hi vimFunction NONE
:hi link vimFunctionError vimError
:hi link vimLineComment vimComment
:hi link vimSpecFile Identifier
:hi link vimOper Operator
:hi vimOperParen NONE
:hi link vimString String
:hi link vimRegister SpecialChar
:hi link vimCmplxRepeat SpecialChar
:hi vimRegion NONE
:hi vimSynLine NONE
:hi link vimNotation Special
:hi link vimCtrlChar SpecialChar
:hi link vimFuncVar Identifier
:hi link vimContinue Special
:hi vimSetEqual NONE
:hi link vimAugroupKey vimCommand
:hi link vimAugroupError vimError
:hi link vimEnvvar PreProc
:hi link vimFunc vimError
:hi link vimType Type
:hi link vimParenSep Delimiter
:hi link vimoperStar vimOper
:hi link vimSep Delimiter
:hi link vimOperError Error
:hi link vimFuncKey vimCommand
:hi link vimFuncSID Special
:hi link vimAbb vimCommand
:hi link vimEchoHL vimCommand
:hi link vimHighlight vimCommand
:hi link vimLetHereDoc vimString
:hi link vimNorm vimCommand
:hi link vimSearch vimString
:hi link vimUnmap vimMap
:hi link vimUserCommand vimCommand
:hi vimFuncBody NONE
:hi vimFuncBlank NONE
:hi link vimPattern Type
:hi link vimSpecFileMod vimSpecFile
:hi vimEscapeBrace NONE
:hi link vimSetString vimString
:hi vimSubstRep NONE
:hi vimSubstRange NONE
:hi link vimUserAttrb vimSpecial
:hi link vimUserAttrbError Error
:hi vimComFilter NONE
:hi link vimUserAttrbKey vimOption
:hi link vimUserAttrbCmplt vimSpecial
:hi link vimUserCmdError Error
:hi link vimUserAttrbCmpltFunc Special
:hi link vimCommentString vimString
:hi link vimPatSepErr vimError
:hi link vimPatSep SpecialChar
:hi link vimPatSepZ vimPatSep
:hi link vimPatSepZone vimString
:hi link vimPatSepR vimPatSep
:hi vimPatRegion NONE
:hi link vimNotPatSep vimString
:hi link vimStringEnd vimString
:hi link vimStringCont vimString
:hi link vimSubstTwoBS vimString
:hi link vimSubstSubstr SpecialChar
:hi vimCollection NONE
:hi vimSubstPat NONE
:hi link vimSubst1 vimSubst
:hi vimSubst2 NONE
:hi link vimSubstDelim Delimiter
:hi vimSubstRep4 NONE
:hi link vimSubstFlagErr vimError
:hi vimCollClass NONE
:hi link vimCollClassErr vimError
:hi link vimSubstFlags Special
:hi link vimMarkNumber vimNumber
:hi link vimPlainMark vimMark
:hi vimRange NONE
:hi link vimPlainRegister vimRegister
:hi link vimSetMod vimOption
:hi link vimSetSep Statement
:hi link vimLetHereDocStart Special
:hi link vimLetHereDocStop Special
:hi link vimMapMod vimBracket
:hi vimMapLhs NONE
:hi vimAutoCmdSpace NONE
:hi vimAutoEventList NONE
:hi vimAutoCmdSfxList NONE
:hi link vimAutoCmdMod Special
:hi link vimEchoHLNone vimGroup
:hi link vimMapBang vimCommand
:hi vimMapRhs NONE
:hi link vimMapModKey vimFuncSID
:hi link vimMapModErr vimError
:hi vimMapRhsExtend NONE
:hi vimMenuBang NONE
:hi vimMenuPriority NONE
:hi link vimMenuName PreProc
:hi link vimMenuMod vimMapMod
:hi link vimMenuNameMore vimMenuName
:hi vimMenuMap NONE
:hi vimMenuRhs NONE
:hi link vimBracket Delimiter
:hi link vimUserFunc Normal
:hi vimUsrCmd NONE
:hi link vimElseIfErr Error
:hi link vimBufnrWarn vimWarn
:hi vimNormCmds NONE
:hi link vimGroupSpecial Special
:hi vimGroupList NONE
:hi link vimSynError Error
:hi link vimSynContains vimSynOption
:hi link vimSynKeyContainedin vimSynContains
:hi link vimSynNextgroup vimSynOption
:hi link vimSynType vimSpecial
:hi vimAuSyntax NONE
:hi link vimSynCase Type
:hi link vimSynCaseError vimError
:hi vimClusterName NONE
:hi link vimGroupName vimGroup
:hi link vimGroupAdd vimSynOption
:hi link vimGroupRem vimSynOption
:hi vimIskList NONE
:hi link vimIskSep Delimiter
:hi link vimSynKeyOpt vimSynOption
:hi vimSynKeyRegion NONE
:hi link vimMtchComment vimComment
:hi link vimSynMtchOpt vimSynOption
:hi link vimSynRegPat vimString
:hi vimSynMatchRegion NONE
:hi vimSynMtchCchar NONE
:hi vimSynMtchGroup NONE
:hi link vimSynPatRange vimString
:hi link vimSynNotPatRange vimSynRegPat
:hi link vimSynRegOpt vimSynOption
:hi link vimSynReg Type
:hi link vimSynMtchGrp vimSynOption
:hi vimSynRegion NONE
:hi vimSynPatMod NONE
:hi link vimSyncC Type
:hi vimSyncLines NONE
:hi vimSyncMatch NONE
:hi link vimSyncError Error
:hi vimSyncLinebreak NONE
:hi vimSyncLinecont NONE
:hi vimSyncRegion NONE
:hi link vimSyncGroupName vimGroupName
:hi link vimSyncKey Type
:hi link vimSyncGroup vimGroupName
:hi link vimSyncNone Type
:hi vimHiLink NONE
:hi link vimHiClear vimHighlight
:hi vimHiKeyList NONE
:hi link vimHiCtermError vimError
:hi vimHiBang NONE
:hi link vimHiGroup vimGroupName
:hi link vimHiAttrib PreProc
:hi link vimFgBgAttrib vimHiAttrib
:hi link vimHiAttribList vimError
:hi vimHiCtermColor NONE
:hi vimHiFontname NONE
:hi vimHiGuiFontname NONE
:hi link vimHiGuiRgb vimNumber
:hi link vimHiTerm Type
:hi link vimHiCTerm vimHiTerm
:hi link vimHiStartStop vimHiTerm
:hi link vimHiCtermFgBg vimHiTerm
:hi link vimHiCtermul vimHiTerm
:hi link vimHiGui vimHiTerm
:hi link vimHiGuiFont vimHiTerm
:hi link vimHiGuiFgBg vimHiTerm
:hi link vimHiKeyError vimError
:hi vimHiTermcap NONE
:hi link vimHiNmbr Number
:hi link vimCommentTitle PreProc
:hi link vim9LineComment vimComment
:hi vimCommentTitleLeader NONE
:hi link vimSearchDelim Statement
:hi link vimEmbedError vimError
:hi vimPythonRegion NONE
:hi link pythonStatement Statement
:hi link pythonFunction Function
:hi link pythonConditional Conditional
:hi link pythonRepeat Repeat
:hi link pythonOperator Operator
:hi link pythonException Exception
:hi link pythonInclude Include
:hi link pythonAsync Statement
:hi link pythonDecorator Define
:hi link pythonDecoratorName Function
:hi link pythonDoctestValue Define
:hi pythonMatrixMultiply NONE
:hi link pythonTodo Todo
:hi link pythonComment Comment
:hi link pythonQuotes String
:hi link pythonEscape Special
:hi link pythonString String
:hi link pythonTripleQuotes pythonQuotes
:hi pythonSpaceError NONE
:hi link pythonDoctest Special
:hi link pythonRawString String
:hi link pythonNumber Number
:hi link pythonBuiltin Function
:hi pythonAttribute NONE
:hi link pythonExceptions Structure
:hi pythonSync NONE
:hi link vimScriptDelim Comment
:hi vimAugroupSyncA NONE
:hi link vimError Error
:hi link vimKeyCodeError vimError
:hi link vimWarn WarningMsg
:hi link vimAuHighlight vimHighlight
:hi link vimAutoCmdOpt vimOption
:hi link vimAutoSet vimCommand
:hi link vimCondHL vimCommand
:hi link vimElseif vimCondHL
:hi link vimFold Folded
:hi link vimSynOption Special
:hi link vimHLMod PreProc
:hi link vimInsert vimString
:hi link vimKeyCode vimSpecFile
:hi link vimKeyword Statement
:hi link vimSpecial Type
:hi link vimStatement Statement
