vim.g.fzf_layout = { down = "35%" }

-- we use different commands in the shell
vim.env.FZF_DEFAULT_COMMAND = "fd --type file --color=never --hidden --strip-cwd-prefix --exclude .git"
