vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.fish',
  group = vim.api.nvim_create_augroup('FishIndentAutoformat', { clear = true }),
  callback = function()
    vim.fn.system('fish_indent ' .. vim.fn.expand('%'))
    vim.cmd('edit!')
  end,
})

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.bzl',
  group = vim.api.nvim_create_augroup('BuildifierAutoformat', { clear = true }),
  callback = function()
    vim.fn.system('buildifier ' .. vim.fn.expand('%'))
    vim.cmd('edit!')
  end,
})
