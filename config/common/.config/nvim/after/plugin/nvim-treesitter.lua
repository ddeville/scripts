local treesitter = require('nvim-treesitter.configs')

treesitter.setup({
  ensure_installed = {
    'bash',
    'c',
    'comment',
    'cpp',
    'css',
    'dockerfile',
    'fish',
    'go',
    'hcl',
    'help',
    'html',
    'java',
    'javascript',
    'json',
    'kotlin',
    'lua',
    'python',
    'rust',
    'toml',
    'typescript',
    'vim',
    'yaml',
  },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
