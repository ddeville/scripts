local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local lazy = require('lazy')

lazy.setup({
  { 'folke/lazy.nvim', tag = 'stable' },

  -- Appearance
  'tinted-theming/base16-vim',
  'itchyny/lightline.vim',
  'ddeville/vim-base16-lightline',
  'mhinz/vim-startify',

  -- Languages
  'dag/vim-fish',
  'fatih/vim-go',
  'rust-lang/rust.vim',
  'hashivim/vim-terraform',
  'baskerville/vim-sxhkdrc',
  'tmux-plugins/vim-tmux',

  -- Code formatters
  'ckipp01/stylua-nvim',
  'z0mbix/vim-shfmt',
  {
    'google/vim-codefmt', -- used for Starlark
    enabled = false, -- quite slow to load, disable until I actually use bazel again...
    dependencies = {
      'google/vim-maktaba',
      'google/vim-glaive',
    },
  },

  -- Navigation
  'mhinz/vim-grepper',
  'mattesgroeger/vim-bookmarks',
  'ddeville/telescope-vim-bookmarks.nvim',

  -- LSP
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'kosayoda/nvim-lightbulb',
      -- TODO(damien): Remove legacy tag once new version has been released https://github.com/j-hui/fidget.nvim
      { 'j-hui/fidget.nvim', tag = 'legacy' },
    },
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-nvim-lua',
      'hrsh7th/vim-vsnip',
      'hrsh7th/cmp-vsnip',
    },
  },

  -- Treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = function()
      pcall(require('nvim-treesitter.install').update({ with_sync = true }))
    end,
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
  },

  -- Telescope
  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/popup.nvim',
      'nvim-lua/plenary.nvim',
    },
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
    cond = function()
      return vim.fn.executable('cmake') == 1
    end,
  },

  -- Magic
  { 'github/copilot.vim', enabled = false },

  -- tpope
  'tpope/vim-commentary',
  'tpope/vim-eunuch',
  'tpope/vim-fugitive',
  'tpope/vim-git',
  'tpope/vim-repeat',
  'tpope/vim-rhubarb',
  'tpope/vim-sleuth',
  'tpope/vim-surround',
  'tpope/vim-unimpaired',
  'tpope/vim-vinegar',
}, {})
