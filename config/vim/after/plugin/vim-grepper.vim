let g:grepper = {}
let g:grepper.tools = ["rg", "git", "grep"]
let g:grepper.highlight = 1

nnoremap <Leader>f :Grepper -tool rg<CR>
nmap gs <plug>(GrepperOperator)
xmap gs <plug>(GrepperOperator)
