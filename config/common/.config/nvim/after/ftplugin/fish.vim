" set up :make to use fish for syntax checking
compiler fish

" set this to have long lines wrap inside comments
setlocal textwidth=79

" use fish_indent to automatically format the buffer with vim-codefmt
AutoFormatBuffer fish_indent
