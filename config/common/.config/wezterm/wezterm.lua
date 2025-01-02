local wezterm = require('wezterm')

local is_macos = string.find(wezterm.target_triple, 'darwin')

local cfg = {}

cfg.term = 'wezterm'
cfg.audible_bell = 'Disabled'
cfg.check_for_updates = false
cfg.window_close_confirmation = 'NeverPrompt'

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
cfg.font_size = is_macos and 14 or 10
cfg.line_height = 1.2

-- Window
cfg.hide_tab_bar_if_only_one_tab = true
cfg.window_padding = { left = 4, right = 4, top = 2, bottom = 2 }
cfg.max_fps = 120
cfg.prefer_egl = true

return cfg
