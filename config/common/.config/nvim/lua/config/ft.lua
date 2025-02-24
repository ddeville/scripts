-- setup filetype for tiltfile
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { 'Tiltfile', '*.Tiltfile' },
  command = 'set filetype=tiltfile',
})

-- setup filetype for Brewfile
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { 'Brewfile' },
  command = 'set filetype=brewfile syntax=brewfile',
})
