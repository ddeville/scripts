local stylua = require('stylua-nvim')

local ag = vim.api.nvim_create_augroup('StyluaAutoformat', { clear = true })
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.lua',
  group = ag,
  callback = stylua.format_file,
})
