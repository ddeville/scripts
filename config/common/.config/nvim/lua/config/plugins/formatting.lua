return {
  'stevearc/conform.nvim',
  config = function()
    local conform = require('conform')

    conform.formatters.shfmt = {
      inherit = false,
      command = 'shfmt',
      args = { '-filename', '$FILENAME', '--simplify', '--indent', '2' },
    }

    conform.setup({
      format_after_save = {
        lsp_fallback = true,
      },
      -- Don't show formatter errors since this gets super annoying and takes
      -- focus when saving with a syntax error.
      notify_on_error = false,
      formatters_by_ft = {
        bzl = { 'buildifier' },
        c = { 'clang_format' },
        cpp = { 'clang_format' },
        cuda = { 'clang_format' },
        fish = { 'fish_indent' },
        go = { 'gofmt' },
        lua = { 'stylua' },
        objc = { 'clang_format' },
        objcpp = { 'clang_format' },
        proto = { 'buf' },
        python = { 'ruff', 'isort' },
        rust = { 'rustfmt' },
        sh = { 'shfmt' },
        terraform = { 'terraform_fmt' },
      },
    })
  end,
}
