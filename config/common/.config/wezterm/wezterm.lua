local wezterm = require("wezterm")

local config = {
	color_scheme = "Gruvbox dark, soft (base16)",
	bold_brightens_ansi_colors = true,
	font = wezterm.font("AnonymicePro Nerd Font"),
	font_rules = {
		{
			intensity = "Bold",
			italic = false,
			font = wezterm.font("AnonymicePro Nerd Font", { weight = "Regular" }),
		},

		{
			intensity = "Bold",
			italic = true,
			font = wezterm.font("AnonymicePro Nerd Font", { weight = "Regular" }),
		},
	},
	font_size = 14,
	line_height = 1.15,
	hide_tab_bar_if_only_one_tab = true,
	window_padding = {
		left = 2,
		right = 2,
		top = 2,
		bottom = 2,
	},
}

return config
