local M = {}

function M.setup(workspaces)
  local exec = hl.dsp.exec_cmd
  local window = hl.dsp.window
  local repeat_key = { repeating = true }

  hl.bind('SUPER + Return', exec('ghostty'))
  hl.bind('SUPER + backslash', exec('google-chrome-stable'))
  for _, key in ipairs({ 'SUPER + space', 'SUPER + d', 'CTRL + space' }) do
    hl.bind(key, exec('qs ipc call launcher toggle'), { release = true })
  end
  hl.bind('SUPER + SHIFT + d', exec('loginctl lock-session'))
  hl.bind('SUPER + SHIFT + s', exec('systemctl suspend'))
  hl.bind('SUPER + Escape', hl.dsp.reload_config())
  hl.bind('SUPER + CTRL + r', hl.dsp.reload_config())
  hl.bind('SUPER + CTRL + q', hl.dsp.exit())

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

  for _, entry in ipairs({ { 'h', 'l', -20, 0 }, { 'j', 'd', 0, 20 }, { 'k', 'u', 0, -20 }, { 'l', 'r', 20, 0 } }) do
    local key, direction, x, y = table.unpack(entry)
    hl.bind('SUPER + ' .. key, hl.dsp.focus({ direction = direction }), repeat_key)
    hl.bind('SUPER + SHIFT + ' .. key, window.swap({ direction = direction }), repeat_key)
    hl.bind('SUPER + ALT + ' .. key, window.resize({ x = math.abs(x), y = math.abs(y), relative = true }), repeat_key)
    hl.bind(
      'SUPER + ALT + SHIFT + ' .. key,
      window.resize({ x = -math.abs(x), y = -math.abs(y), relative = true }),
      repeat_key
    )
  end
  for _, entry in ipairs({ { 'Left', -20, 0 }, { 'Down', 0, 20 }, { 'Up', 0, -20 }, { 'Right', 20, 0 } }) do
    hl.bind('SUPER + ' .. entry[1], window.move({ x = entry[2], y = entry[3], relative = true }), repeat_key)
  end
  hl.bind('SUPER + c', window.cycle_next())
  hl.bind('SUPER + SHIFT + c', window.cycle_next({ next = false }))
  hl.bind('SUPER + grave', hl.dsp.focus({ last = true }))
  hl.bind('SUPER + Tab', hl.dsp.focus({ workspace = 'previous_per_monitor' }))
  hl.bind('SUPER + g', function()
    local active = hl.get_active_window()
    if not active then
      return
    end
    local largest
    for _, candidate in ipairs(hl.get_workspace_windows(active.workspace)) do
      if
        candidate ~= active
        and not candidate.floating
        and (not largest or candidate.size.x * candidate.size.y > largest.size.x * largest.size.y)
      then
        largest = candidate
      end
    end
    if largest then
      hl.dispatch(window.swap({ target = largest }))
    end
  end)

  for index = 1, 10 do
    local key = tostring(index % 10)
    hl.bind('SUPER + ' .. key, function()
      workspaces.select(index, false)
    end)
    hl.bind('SUPER + SHIFT + ' .. key, function()
      workspaces.select(index, true)
    end)
  end
  hl.bind('SUPER + bracketleft', function()
    workspaces.cycle(-1)
  end)
  hl.bind('SUPER + bracketright', function()
    workspaces.cycle(1)
  end)
  -- Monitor navigation is symmetric; Ctrl adds sending the active window.
  hl.bind('SUPER + SHIFT + bracketleft', hl.dsp.focus({ monitor = '-1' }))
  hl.bind('SUPER + SHIFT + bracketright', hl.dsp.focus({ monitor = '+1' }))
  hl.bind('SUPER + CTRL + SHIFT + bracketleft', window.move({ monitor = '-1' }))
  hl.bind('SUPER + CTRL + SHIFT + bracketright', window.move({ monitor = '+1' }))
  hl.bind('SUPER + mouse:272', window.drag(), { mouse = true })
  hl.bind('SUPER + mouse:273', window.resize(), { mouse = true })

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
  hl.bind('CTRL + period', exec('dunstctl close'))
  hl.bind('CTRL + SHIFT + period', exec('dunstctl close-all'))
  hl.bind('CTRL + ALT + period', exec('dunstctl history-pop'))
  hl.bind('CTRL + SHIFT + 3', exec('qs ipc call screenshot capture full'), { release = true })
  hl.bind('CTRL + SHIFT + 4', exec('qs ipc call screenshot capture region'), { release = true })
end

return M
