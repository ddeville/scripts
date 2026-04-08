-- setup filetype for tiltfile
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { 'Tiltfile', '*.Tiltfile' },
  callback = function()
    vim.bo.filetype = 'tiltfile'
  end,
})

-- setup filetype for Brewfile
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { 'Brewfile' },
  callback = function()
    vim.bo.filetype = 'brewfile'
    vim.bo.syntax = 'brewfile'
  end,
})
