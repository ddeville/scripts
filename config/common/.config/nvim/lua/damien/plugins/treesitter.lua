return {
  {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      require('nvim-treesitter.configs').setup({
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
          'vimdoc',
          'yaml',
        },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      })
    end,
    build = function()
      pcall(require('nvim-treesitter.install').update({ with_sync = true }))
    end,
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
  },
}
