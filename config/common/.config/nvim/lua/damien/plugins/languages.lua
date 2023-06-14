return {
  {
    'rust-lang/rust.vim',
    ft = 'rust',
    config = function()
      vim.g.rustfmt_autosave = 1
      vim.g.rustfmt_emit_files = 1
      vim.g.rustfmt_fail_silently = 0
    end,
  },
  {
    'fatih/vim-go',
    ft = 'go',
    config = function()
      -- we use nvim-lsp instead
      vim.g.go_gopls_enabled = 0
      vim.g.go_code_completion_enabled = 0
      vim.g.go_def_mapping_enabled = 0
      vim.g.go_diagnostics_enabled = 0
      vim.g.go_echo_go_info = 0
      vim.g.go_metalinter_enabled = 0
      vim.g.go_fmt_autosave = 1
      vim.g.go_imports_mode = 'gopls'
    end,
  },
  {
    'dag/vim-fish',
    ft = 'fish',
  },
  { 'hashivim/vim-terraform', ft = 'terraform' },
  { 'baskerville/vim-sxhkdrc', ft = 'sxhkdrc' },
  { 'tmux-plugins/vim-tmux', ft = 'tmux' },
}
