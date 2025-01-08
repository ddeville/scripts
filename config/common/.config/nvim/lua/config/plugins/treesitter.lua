return {
  {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = {
          'awk',
          'bash',
          'c',
          'cmake',
          'comment',
          'cpp',
          'css',
          'diff',
          'dockerfile',
          'fish',
          'git_config',
          'git_rebase',
          'gitattributes',
          'gitignore',
          'go',
          'gomod',
          'gosum',
          'gowork',
          'hcl',
          'html',
          'java',
          'javascript',
          'json',
          'jq',
          'kotlin',
          'lua',
          'luadoc',
          'make',
          'markdown',
          'ninja',
          'objc',
          'proto',
          'python',
          'regex',
          'rust',
          'sql',
          'starlark',
          'sxhkdrc',
          'terraform',
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

      -- Use the starlark config for tiltfile
      vim.treesitter.language.register('starlark', 'tiltfile')
    end,
    build = function()
      pcall(require('nvim-treesitter.install').update({ with_sync = true }))
    end,
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
  },
}
