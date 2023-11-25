return {
  'stevearc/conform.nvim',
  config = function()
    local conform = require('conform')

    conform.formatters.shfmt = {
      inherit = false,
      command = 'shfmt',
      args = { '-filename', '$FILENAME', '--simplify', '--indent', '2' },
    }
    conform.formatters.black = {
      inherit = false,
      command = 'black',
      args = {
        '--stdin-filename',
        '$FILENAME',
        '--quiet',
        '--line-length',
        '100',
        '-',
      },
    }

    conform.setup({
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
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
        python = { 'ruff', 'black' },
        rust = { 'rustfmt' },
        sh = { 'shfmt' },
        terraform = { 'terraform_fmt' },
      },
    })
  end,
}
