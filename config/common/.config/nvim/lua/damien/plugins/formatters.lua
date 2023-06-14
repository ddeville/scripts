return {
  {
    'ckipp01/stylua-nvim',
    config = function()
      local ag = vim.api.nvim_create_augroup('StyluaAutoformat', { clear = true })
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = '*.lua',
        group = ag,
        callback = require('stylua-nvim').format_file,
      })
    end,
  },
  {
    'z0mbix/vim-shfmt',
    config = function()
      vim.g.shfmt_fmt_on_save = 1
      vim.g.shfmt_extra_args = '--simplify --indent 2'

      -- `shfmt_fmt_on_save` doesn't seem to work so let's do it manually instead...
      local ag = vim.api.nvim_create_augroup('ShfmtAutoformat', { clear = true })
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'sh',
        group = ag,
        nested = true,
        command = [[autocmd BufWritePre <buffer> Shfmt]],
      })
    end,
  },
  {
    'google/vim-codefmt', -- used for Starlark
    enabled = false, -- quite slow to load, disable until I actually use bazel again...
    dependencies = {
      'google/vim-maktaba',
      'google/vim-glaive',
    },
  },
}
