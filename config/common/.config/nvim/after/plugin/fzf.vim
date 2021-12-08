let g:fzf_layout = { "down": "35%" }

" we use different commands in the shell
let $FZF_DEFAULT_COMMAND = "fd --type file --color=never --hidden --strip-cwd-prefix --exclude .git"

nnoremap <Leader>; :Buffers<CR>
nnoremap ; :Buffers<CR>
nnoremap <Leader>o :Files<CR>
nnoremap <C-p> :Files<CR>
nnoremap <Leader>s :GFiles?<CR>
nnoremap <Leader>t :Tags<CR>
nnoremap // :BLines<CR>
