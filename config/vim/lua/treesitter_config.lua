local treesitter = require('nvim-treesitter.configs')

treesitter.setup {
  ensure_installed = { "c", "cpp", "fish", "go", "java", "javascript", "lua", "python", "rust", "toml", "typescript"},
  highlight = {
    enable = true,
  },
}
