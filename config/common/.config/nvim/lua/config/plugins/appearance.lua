return {
  'mhinz/vim-startify',
  {
    'ellisonleao/gruvbox.nvim',
    config = function()
      require('gruvbox').setup({
        terminal_colors = true,
        undercurl = false,
        underline = false,
        bold = false,
        italic = {
          strings = false,
          emphasis = true,
          comments = true,
          operators = false,
          folds = true,
        },
        strikethrough = false,
        contrast = '', -- can be "hard", "soft" or empty string
      })
      vim.cmd('colorscheme gruvbox')
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      -- don't show `-- INSERT --` since we have a fancy status line
      vim.opt.showmode = false

      require('lualine').setup({
        options = {
          icons_enabled = false,
          theme = function()
            -- Rebuild from the current background without modifying the cached theme.
            local gruvbox = vim.deepcopy(require('lualine.themes.gruvbox_' .. vim.o.background))
            -- Keep the familiar insert/command color swap.
            gruvbox.command.a.bg, gruvbox.insert.a.bg = gruvbox.insert.a.bg, gruvbox.command.a.bg
            -- Only the mode component changes color between modes.
            for _, mode in ipairs({ 'insert', 'visual', 'replace', 'command' }) do
              gruvbox[mode].c.bg = gruvbox.normal.c.bg
              gruvbox[mode].c.fg = gruvbox.normal.c.fg
            end
            return gruvbox
          end,
          component_separators = { left = '|', right = '|' },
          section_separators = { left = '', right = '' },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch' },
          lualine_c = { 'filename' },
          lualine_x = { 'diagnostics', 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { 'filename' },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {},
        },
        extensions = { 'quickfix' },
      })
    end,
  },
}
