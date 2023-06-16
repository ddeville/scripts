return {
  'mhinz/vim-startify',
  'tinted-theming/base16-vim',
  'ddeville/vim-base16-lightline',
  {
    'itchyny/lightline.vim',
    config = function()
      -- don't show `-- INSERT --` since we have a fancy status line
      vim.opt.showmode = false

      -- color scheme and items
      vim.g.lightline = {
        colorscheme = 'base16',
        active = {
          left = { { 'mode', 'paste' }, { 'gitbranch', 'readonly', 'filename', 'modified' }, { 'lsp_status' } },
        },
        component_function = {
          gitbranch = 'fugitive#Head',
        },
      }
    end,
  },
}
