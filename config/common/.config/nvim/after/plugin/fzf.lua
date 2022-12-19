vim.g.fzf_layout = { down = "35%" }

-- we use different commands in the shell
vim.env.FZF_DEFAULT_COMMAND = "fd --type file --color=never --hidden --strip-cwd-prefix --exclude .git"

vim.keymap.set("n", "<leader>;", ":Buffers<CR>")
vim.keymap.set("n", ";", ":Buffers<CR>")
vim.keymap.set("n", "<leader>o", ":Files<CR>")
vim.keymap.set("n", "<C-p>", ":Files<CR>")
vim.keymap.set("n", "<leader>s", ":GFiles?<CR>")
vim.keymap.set("n", "<leader>t", ":Tags<CR>")
vim.keymap.set("n", "//", ":BLines<CR>")
