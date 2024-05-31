return {
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    config = function()
      vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
      vim.opt.shortmess:append('c')

      local cmp = require('cmp')

      cmp.setup({
        sources = {
          { name = 'copilot' },
          { name = 'nvim_lsp' },
          { name = 'nvim_lua' },
          { name = 'vsnip' },
          { name = 'path' },
          { name = 'buffer', keyword_length = 2 },
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-e>'] = cmp.mapping.abort(),
          ['<C-y>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
          }),
          ['<C-d>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
        }),
        formatting = {
          format = function(entry, vim_item)
            local menu = {
              copilot = '[Copilot]',
              nvim_lsp = '[LSP]',
              nvim_lua = '[API]',
              vsnip = '[Snip]',
              path = '[Path]',
              buffer = '[Buf]',
            }
            vim_item.menu = menu[entry.source.name]
            return vim_item
          end,
        },
        snippet = {
          expand = function(args)
            vim.fn['vsnip#anonymous'](args.body)
          end,
        },
      })
    end,
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-nvim-lua',
      'hrsh7th/vim-vsnip',
      'hrsh7th/cmp-vsnip',
    },
  },
}
