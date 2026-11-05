hl.monitor({ output = '', mode = 'preferred', position = 'auto', scale = 1.6 })
hl.config({
  animations = { enabled = false },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_hyprland_guiutils_check = true,
  },
  xwayland = { enabled = false },
})
hl.on('hyprland.start', function()
  hl.exec_cmd("regreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
