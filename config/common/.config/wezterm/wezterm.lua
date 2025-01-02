local wezterm = require('wezterm')

local cfg = {}

-- Colorscheme
cfg.color_scheme = 'Gruvbox dark, soft (base16)'
cfg.bold_brightens_ansi_colors = true

-- Font
cfg.font = wezterm.font('AnonymicePro Nerd Font')
cfg.font_rules = {
  {
    intensity = 'Bold',
    italic = false,
    font = wezterm.font('AnonymicePro Nerd Font', { weight = 'Regular' }),
  },

  {
    intensity = 'Bold',
    italic = true,
    font = wezterm.font('AnonymicePro Nerd Font', { weight = 'Regular' }),
  },
}
cfg.font_size = 14
cfg.line_height = 1.15

-- Window
cfg.hide_tab_bar_if_only_one_tab = true
cfg.window_padding = { left = 4, right = 4, top = 2, bottom = 2 }

return cfg
