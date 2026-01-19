" Vim syntax file
" Language:    FreeMarker Template Language (FTL)
" Maintainer:  Stephan Müller <stephan@notatoaster.org>
" Last Change: 2008 Oct 22 (Modified for HTML support)

" Pour Neovim, on veut charger HTML en premier
if exists('b:current_syntax')
  unlet b:current_syntax
endif

" Charger la syntaxe HTML en premier
runtime! syntax/html.vim
unlet! b:current_syntax

syn case match

" directives and interpolations
syn region ftlStartDirective start=+<#+ end=+>+ contains=ftlKeyword,ftlDirective,ftlString,ftlComment
syn region ftlEndDirective start=+</#+ end=+>+ contains=ftlDirective
syn region ftlStartDirectiveAlt start=+\[#+ end=+\]+ contains=ftlKeyword,ftlDirective,ftlString,ftlComment
syn region ftlEndDirectiveAlt start=+\[/#+ end=+\]+ contains=ftlDirective
syn region ftlStartUserDirective start=+<@+ end=+>+ contains=ftlString,ftlComment
syn region ftlEndUserDirective start=+</@+ end=+>+
syn region ftlStartUserDirectiveAlt start=+\[@+ end=+\]+ contains=ftlString,ftlComment
syn region ftlEndUserDirectiveAlt start=+\[/@+ end=+\]+
syn region ftlInterpolation start=+${+ end=+}+
syn region ftlInterpolation2 start=+#{+ end=+}+
syn region ftlString contained start=+"+ end=+"+
syn region ftlComment start=+<#--+ end=+-->+
syn region ftlCommentAlt start=+\[#--+ end=+--\]+

" keywords
syn keyword ftlDirective contained list if else macro import include switch case break
syn keyword ftlDirective contained assign local global nested recurse fallback visit
syn keyword ftlDirective contained function return t rt lt nt ftl
syn keyword ftlKeyword contained as in using

" highlighting
if version < 508
  command! -nargs=+ FtlHiLink hi link <args>
else
  command! -nargs=+ FtlHiLink hi def link <args>
endif

FtlHiLink ftlKeyword Statement
FtlHiLink ftlDirective Statement
FtlHiLink ftlStartDirective Function
FtlHiLink ftlEndDirective Function
FtlHiLink ftlStartUserDirective Function
FtlHiLink ftlEndUserDirective Function
FtlHiLink ftlInterpolation Constant
FtlHiLink ftlInterpolation2 Constant
FtlHiLink ftlString Constant
FtlHiLink ftlComment Comment

delcommand FtlHiLink

" Important: définir comme "ftl" seulement pour que html.ftl fonctionne
let b:current_syntax = "ftl"
