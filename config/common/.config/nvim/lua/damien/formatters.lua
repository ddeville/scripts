vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.fish',
  group = vim.api.nvim_create_augroup('FishIndentAutoformat', { clear = true }),
  callback = function()
    local pos = vim.fn.getpos('.')
    vim.cmd('%!fish_indent')
    vim.fn.setpos('.', pos)
  end,
})

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.bzl',
  group = vim.api.nvim_create_augroup('BuildifierAutoformat', { clear = true }),
  callback = function()
    local pos = vim.fn.getpos('.')
    vim.cmd('%!buildifier')
    vim.fn.setpos('.', pos)
  end,
})
