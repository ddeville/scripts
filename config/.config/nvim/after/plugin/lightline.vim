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
  if has("nvim-0.5") && luaeval("not vim.tbl_isempty(vim.lsp.buf_get_clients(0))")
    let l:msg = luaeval("require('lsp-status').status_progress()")
    " lsp-status seems to double encode the % signs so fix that here
    let l:msg = substitute(l:msg, "%%", "%", "")
    " make sure that we don't overflow the line towards the left
    return l:msg[0:(winwidth(0) - 70)]
  else
    return ""
  endif
endfunction
