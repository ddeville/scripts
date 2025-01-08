-- setup filetype for tiltfile
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { 'Tiltfile', '*.Tiltfile' },
  command = 'set filetype=tiltfile',
})
