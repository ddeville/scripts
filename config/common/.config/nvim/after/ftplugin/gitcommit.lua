-- Otherwise the commit message is red and overflow white when using gruvbox.
vim.api.nvim_set_hl(0, 'gitcommitSummary', { link = 'gitcommitDiff' })
vim.api.nvim_set_hl(0, 'gitcommitOverflow', { link = 'WarningMsg' })
