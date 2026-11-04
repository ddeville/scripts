local M = {}

function M.setup(workspace_count)
  local exec = hl.dsp.exec_cmd
  local window = hl.dsp.window
  local repeat_key = { repeating = true }

  -- Applications
  hl.bind('SUPER + Return', exec('ghostty'))
  hl.bind('SUPER + backslash', exec('google-chrome-stable'))
  -- Open after key release so the shortcut does not become input to the launcher.
  for _, key in ipairs({ 'SUPER + space', 'SUPER + d', 'CTRL + space' }) do
    hl.bind(key, exec('qs ipc call launcher toggle'), { release = true })
  end

  -- Session
  hl.bind('SUPER + SHIFT + d', exec('loginctl lock-session'), { release = true })
  hl.bind('SUPER + SHIFT + s', exec('systemctl suspend'))
  hl.bind('SUPER + Escape', hl.dsp.reload_config())
  hl.bind('SUPER + CTRL + r', hl.dsp.reload_config())
  hl.bind('SUPER + CTRL + q', hl.dsp.exit())

  -- Window state
  hl.bind('SUPER + w', window.close())
  hl.bind('SUPER + SHIFT + w', window.kill())
  hl.bind('SUPER + t', function()
    hl.dispatch(window.float({ action = 'disable' }))
    hl.dispatch(window.pseudo({ action = 'disable' }))
  end)
  hl.bind('SUPER + SHIFT + t', function()
    hl.dispatch(window.float({ action = 'disable' }))
    hl.dispatch(window.pseudo({ action = 'enable' }))
  end)
  hl.bind('SUPER + s', window.float({ action = 'enable' }))
  hl.bind('SUPER + f', window.fullscreen({ mode = 'fullscreen' }))
  hl.bind('SUPER + m', window.fullscreen({ mode = 'maximized' }))
  hl.bind('SUPER + CTRL + y', window.pin())

  -- Window focus
  hl.bind('SUPER + h', hl.dsp.focus({ direction = 'l' }), repeat_key)
  hl.bind('SUPER + j', hl.dsp.focus({ direction = 'd' }), repeat_key)
  hl.bind('SUPER + k', hl.dsp.focus({ direction = 'u' }), repeat_key)
  hl.bind('SUPER + l', hl.dsp.focus({ direction = 'r' }), repeat_key)
  hl.bind('SUPER + c', window.cycle_next())
  hl.bind('SUPER + SHIFT + c', window.cycle_next({ next = false }))
  hl.bind('SUPER + grave', hl.dsp.focus({ last = true }))

  -- Swap windows
  hl.bind('SUPER + SHIFT + h', window.swap({ direction = 'l' }), repeat_key)
  hl.bind('SUPER + SHIFT + j', window.swap({ direction = 'd' }), repeat_key)
  hl.bind('SUPER + SHIFT + k', window.swap({ direction = 'u' }), repeat_key)
  hl.bind('SUPER + SHIFT + l', window.swap({ direction = 'r' }), repeat_key)

  -- Grow / shrink windows
  hl.bind('SUPER + ALT + h', window.resize({ x = 20, y = 0, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + j', window.resize({ x = 0, y = 20, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + k', window.resize({ x = 0, y = 20, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + l', window.resize({ x = 20, y = 0, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + SHIFT + h', window.resize({ x = -20, y = 0, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + SHIFT + j', window.resize({ x = 0, y = -20, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + SHIFT + k', window.resize({ x = 0, y = -20, relative = true }), repeat_key)
  hl.bind('SUPER + ALT + SHIFT + l', window.resize({ x = -20, y = 0, relative = true }), repeat_key)

  -- Move floating windows; drag or resize with the mouse
  hl.bind('SUPER + Left', window.move({ x = -20, y = 0, relative = true }), repeat_key)
  hl.bind('SUPER + Down', window.move({ x = 0, y = 20, relative = true }), repeat_key)
  hl.bind('SUPER + Up', window.move({ x = 0, y = -20, relative = true }), repeat_key)
  hl.bind('SUPER + Right', window.move({ x = 20, y = 0, relative = true }), repeat_key)
  hl.bind('SUPER + mouse:272', window.drag(), { mouse = true })
  hl.bind('SUPER + mouse:273', window.resize(), { mouse = true })

  -- Workspaces and monitors
  -- Bind only configured workspaces; 0 selects workspace 10 when present.
  for id = 1, math.min(workspace_count, 10) do
    local key = tostring(id % 10)
    hl.bind('SUPER + ' .. key, hl.dsp.focus({ workspace = id }))
    hl.bind('SUPER + SHIFT + ' .. key, window.move({ workspace = id }))
  end
  hl.bind('SUPER + bracketleft', hl.dsp.focus({ workspace = 'e-1' }))
  hl.bind('SUPER + bracketright', hl.dsp.focus({ workspace = 'e+1' }))
  hl.bind('SUPER + Tab', hl.dsp.focus({ workspace = 'previous' }))
  -- Monitor navigation is symmetric; Ctrl adds sending the active window.
  hl.bind('SUPER + SHIFT + bracketleft', hl.dsp.focus({ monitor = '-1' }))
  hl.bind('SUPER + SHIFT + bracketright', hl.dsp.focus({ monitor = '+1' }))
  hl.bind('SUPER + CTRL + SHIFT + bracketleft', window.move({ monitor = '-1' }))
  hl.bind('SUPER + CTRL + SHIFT + bracketright', window.move({ monitor = '+1' }))

  -- Audio and brightness
  hl.bind(
    'XF86AudioRaiseVolume',
    exec('pactl set-sink-volume @DEFAULT_SINK@ +1% && qs ipc call osd volume'),
    repeat_key
  )
  hl.bind(
    'XF86AudioLowerVolume',
    exec('pactl set-sink-volume @DEFAULT_SINK@ -1% && qs ipc call osd volume'),
    repeat_key
  )
  hl.bind('XF86AudioMute', exec('pactl set-sink-mute @DEFAULT_SINK@ toggle && qs ipc call osd volume'))
  hl.bind('XF86AudioPlay', exec('playerctl --player=spotify play-pause'))
  hl.bind('XF86AudioPrev', exec('playerctl --player=spotify previous'))
  hl.bind('XF86AudioNext', exec('playerctl --player=spotify next'))
  hl.bind('XF86MonBrightnessDown', exec('brightnessctl set 5%- && qs ipc call osd brightness'), repeat_key)
  hl.bind('XF86MonBrightnessUp', exec('brightnessctl set 5%+ && qs ipc call osd brightness'), repeat_key)

  -- Notifications and screenshots
  hl.bind('CTRL + period', exec('dunstctl close'))
  hl.bind('CTRL + SHIFT + period', exec('dunstctl close-all'))
  hl.bind('CTRL + ALT + period', exec('dunstctl history-pop'))
  hl.bind('CTRL + SHIFT + 3', exec('qs ipc call screenshot capture full'), { release = true })
  hl.bind('CTRL + SHIFT + 4', exec('qs ipc call screenshot capture region'), { release = true })
end

return M
