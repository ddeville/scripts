local hostname_file = assert(io.open('/etc/hostname'))
local hostname = hostname_file:read('*l')
hostname_file:close()

hl.env('XCURSOR_THEME', 'Adwaita')
hl.env('XCURSOR_SIZE', '24')
hl.env('HYPRCURSOR_SIZE', '24')
hl.env('QT_QPA_PLATFORM', 'wayland;xcb')

hl.config({
  general = {
    layout = 'dwindle',
    gaps_in = 0,
    gaps_out = 0,
    border_size = 1,
    col = { active_border = 'rgb(ffaf00)', inactive_border = 'rgb(504945)' },
  },
  -- Keep split orientations stable; place new windows to the right or below.
  dwindle = { preserve_split = true, default_split_ratio = 1.0, force_split = 2 },
  decoration = {
    rounding = 0,
    shadow = { enabled = false },
    blur = { enabled = true, size = 8, passes = 3 },
  },
  animations = { enabled = false },
  input = {
    repeat_delay = 180,
    repeat_rate = 50,
    follow_mouse = 0,
    touchpad = {
      natural_scroll = true,
      tap_to_click = false,
      clickfinger_behavior = true,
    },
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    focus_on_activate = true, -- Follow existing windows when opening links or files.
  },
})

-- Unknown displays use automatic settings; positions below are logical pixels after scaling.
hl.monitor({ output = '', mode = 'preferred', position = 'auto', scale = 'auto' })
if hostname == 'framework' then
  hl.monitor({ output = 'eDP-1', mode = '2256x1504', position = '0x0', scale = 1.6 })
elseif hostname == 'arch' then
  hl.monitor({ output = 'DP-1', mode = '3840x2160', position = '0x853', scale = 1.5 })
  hl.monitor({ output = 'DP-2', mode = '3840x2160', position = '2560x0', scale = 1.5, transform = 3 })
end

-- Let windows for those programs float.
for _, class in ipairs({
  'com.onepassword.OnePassword',
  'org.pulseaudio.pavucontrol',
  'pavucontrol',
  'nm-connection-editor',
  'Nm-connection-editor',
  'QjackCtl',
  'org.rncbc.qjackctl',
}) do
  hl.window_rule({ match = { class = class }, float = true })
end

local workspaces = require('workspaces').setup(hostname)
require('bindings').setup(#workspaces)

-- Start session services once; reloading settings should not launch more copies.
hl.on('hyprland.start', function()
  hl.exec_cmd('"$HOME/.config/hypr/session.sh"')
end)
