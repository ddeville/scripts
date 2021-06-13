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

" retrieve the LSP status so that we can show it in the lightline
function! LspStatus() abort
  if has("nvim")
    let l:msg = luaeval("require('lsp-status').status_progress()")
    let l:space = winwidth(0) - 70
    if strlen(msg) > space
      return msg[0:space]
    else
      return msg
    endif
  else
    return ""
  endif
endfunction
