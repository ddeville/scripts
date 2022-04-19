vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.shortmess:append "c"

local cmp = require("cmp")

vim.api.nvim_set_hl(0, "CmpItemAbbr", { fg = "Gray", ctermfg = "Gray" })
vim.api.nvim_set_hl(0, "CmpItemAbbrDeprecated", { fg = "Red", ctermfg = "Red" })
vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { fg = "Yellow", ctermfg = "Yellow", underline = true })
vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", { fg = "Yellow", ctermfg = "Yellow", underline = true })
vim.api.nvim_set_hl(0, "CmpItemKind", { fg = "Green", ctermfg = "Green" })
vim.api.nvim_set_hl(0, "CmpItemMenu", { fg = "Magenta", ctermfg = "Magenta" })

cmp.setup({
  sources = {
    { name = "nvim_lsp" },
    { name = "nvim_lua" },
    { name = "vsnip" },
    { name = "path" },
    { name = "buffer", keyword_length = 3 },
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-e>"] = cmp.mapping.abort(),
    ["<C-y>"] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    },
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
  }),
  formatting = {
    format = function(entry, vim_item)
      local menu = {
        nvim_lsp = "[LSP]",
        nvim_lua = "[API]",
        vsnip = "[Snip]",
        path = "[Path]",
        buffer = "[Buf]",
      }
      vim_item.menu = menu[entry.source.name]
      return vim_item
    end,
  },
  snippet = {
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body)
    end,
  },
})
