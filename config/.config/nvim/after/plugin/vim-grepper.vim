let g:grepper = {}
let g:grepper.tools = ["rg", "git", "grep"]
let g:grepper.highlight = 1

" Fix for https://github.com/BurntSushi/ripgrep/issues/1892
let g:grepper.rg = { "grepprg":    "rg -H --no-heading --vimgrep $* ."}
  \                  "grepformat": "%f:%l:%c:%m,%f",
  \                  "escape":     "\^$.*+?()[]{}|" }

nnoremap <Leader>f :Grepper -tool rg<CR>
nmap gs <plug>(GrepperOperator)
xmap gs <plug>(GrepperOperator)
