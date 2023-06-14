return {
  { 'folke/lazy.nvim', tag = 'stable' },

  -- LSP
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'kosayoda/nvim-lightbulb',
      -- TODO(damien): Remove legacy tag once new version has been released https://github.com/j-hui/fidget.nvim
      { 'j-hui/fidget.nvim', tag = 'legacy' },
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
}