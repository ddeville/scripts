local ag = vim.api.nvim_create_augroup('CodeFmtAutoformat', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'bzl',
  group = ag,
  command = 'AutoFormatBuffer buildifier',
})
