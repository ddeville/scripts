" don't show `-- INSERT --` since we have a fancy status line
set noshowmode

" update color scheme
let g:lightline =
\ {
\   "colorscheme": "wombat",
\   "active": {
\     "left": [["mode", "paste"], ["gitbranch", "readonly", "filename", "modified"], ["lsp_status"]],
\   },
\   "component_function": {
\     "gitbranch": "fugitive#Head",
\     "lsp_status": "LspStatus",
\   },
\ }
