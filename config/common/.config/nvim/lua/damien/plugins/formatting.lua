return {
  {
    'jose-elias-alvarez/null-ls.nvim',
    config = function()
      local null_ls = require('null-ls')

      local ag = vim.api.nvim_create_augroup('LspFormatting', {})

      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.buildifier,
          null_ls.builtins.formatting.fish_indent,
          null_ls.builtins.formatting.gofmt,
          null_ls.builtins.formatting.ruff,
          null_ls.builtins.formatting.rustfmt,
          null_ls.builtins.formatting.shfmt.with({ args = { '-filename', '$FILENAME', '--simplify', '--indent', '2' } }),
          null_ls.builtins.formatting.stylua,
        },
        on_attach = function(client, bufnr)
          -- Disable LSP semantic tokens since we use treesitter for syntax highlighting anyway...
          -- (see https://www.reddit.com/r/neovim/comments/109vgtl/how_to_disable_highlight_from_lsp)
          client.server_capabilities.semanticTokensProvider = nil

          if client.supports_method('textDocument/formatting') then
            vim.api.nvim_clear_autocmds({ group = ag, buffer = bufnr })
            vim.api.nvim_create_autocmd('BufWritePre', {
              group = ag,
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.format({
                  async = false,
                  bufnr = bufnr,
                  filter = function(c)
                    return c.name == 'null-ls'
                  end,
                })
              end,
            })
          end
        end,
      })
    end,
  },
}
