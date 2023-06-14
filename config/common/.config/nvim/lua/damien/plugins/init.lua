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
}
