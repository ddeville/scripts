local M = {}

local directions = {
  { key = 'h', arrow = 'Left', direction = 'l', x = -20, y = 0 },
  { key = 'j', arrow = 'Down', direction = 'd', x = 0, y = 20 },
  { key = 'k', arrow = 'Up', direction = 'u', x = 0, y = -20 },
  { key = 'l', arrow = 'Right', direction = 'r', x = 20, y = 0 },
}

local function swap_largest_window()
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
    hl.dispatch(hl.dsp.window.swap({ target = largest }))
  end
end

function M.setup()
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
  hl.bind('SUPER + SHIFT + d', exec('loginctl lock-session'))
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

  -- Window navigation and geometry
  -- HJKL focuses; Shift swaps; Alt grows along that axis and Alt+Shift shrinks.
  for _, entry in ipairs(directions) do
    local key = entry.key
    local x, y = math.abs(entry.x), math.abs(entry.y)
    hl.bind('SUPER + ' .. key, hl.dsp.focus({ direction = entry.direction }), repeat_key)
    hl.bind('SUPER + SHIFT + ' .. key, window.swap({ direction = entry.direction }), repeat_key)
    hl.bind('SUPER + ALT + ' .. key, window.resize({ x = x, y = y, relative = true }), repeat_key)
    hl.bind('SUPER + ALT + SHIFT + ' .. key, window.resize({ x = -x, y = -y, relative = true }), repeat_key)
    hl.bind('SUPER + ' .. entry.arrow, window.move({ x = entry.x, y = entry.y, relative = true }), repeat_key)
  end
  hl.bind('SUPER + c', window.cycle_next())
  hl.bind('SUPER + SHIFT + c', window.cycle_next({ next = false }))
  hl.bind('SUPER + grave', hl.dsp.focus({ last = true }))
  hl.bind('SUPER + g', swap_largest_window)
  hl.bind('SUPER + mouse:272', window.drag(), { mouse = true })
  hl.bind('SUPER + mouse:273', window.resize(), { mouse = true })

  -- Workspaces and monitors
  -- Workspace IDs continue across monitors; 0 selects workspace 10.
  for id = 1, 10 do
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
