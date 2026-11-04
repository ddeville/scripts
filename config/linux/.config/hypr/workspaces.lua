local M = {}

function M.setup(hostname)
  local configured = {}
  local floating = {}
  local function configure(monitor)
    if configured[monitor.name] then
      return
    end
    configured[monitor.name] = true
    local base, names
    if hostname == 'arch' and monitor.name == 'DP-1' then
      base, names = 0, { 'web', 'media', 'flt', 'a', 'b', 'c' }
    elseif hostname == 'arch' and monitor.name == 'DP-2' then
      base, names = 10, { 'code', 'a', 'b', 'c' }
    elseif monitor.name == 'eDP-1' or (hostname ~= 'arch' and hostname ~= 'framework' and monitor.id == 0) then
      base, names = 0, { 'web', 'code', 'media', 'flt', 'a', 'b', 'c' }
    else
      base, names = 100 + monitor.id * 10, { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10' }
    end
    for index, name in ipairs(names) do
      local id = base + index
      hl.workspace_rule({
        workspace = tostring(id),
        monitor = monitor.name,
        default = index == 1,
        default_name = name,
        persistent = true,
      })
      if name == 'flt' then
        floating[id] = true
        hl.window_rule({ match = { workspace = tostring(id) }, float = true })
      end
    end
  end
  local function configure_all()
    for _, monitor in ipairs(hl.get_monitors()) do
      configure(monitor)
    end
  end
  hl.on('hyprland.start', configure_all)
  hl.on('config.reloaded', configure_all)
  hl.on('monitor.added', configure)
  hl.on('window.move_to_workspace', function(window, workspace)
    if floating[workspace.id] then
      hl.dispatch(hl.dsp.window.float({ window = window, action = 'enable' }))
    end
  end)
end

function M.current_monitor()
  local monitor = hl.get_active_monitor()
  local result = {}
  for _, workspace in ipairs(hl.get_workspaces()) do
    if not workspace.special and workspace.id and workspace.monitor == monitor then
      table.insert(result, workspace)
    end
  end
  table.sort(result, function(a, b)
    return a.id < b.id
  end)
  return result
end

function M.select(index, move)
  local workspace = M.current_monitor()[index]
  if workspace then
    hl.dispatch(move and hl.dsp.window.move({ workspace = workspace }) or hl.dsp.focus({ workspace = workspace }))
  end
end

function M.cycle(delta)
  local workspaces = M.current_monitor()
  for index, workspace in ipairs(workspaces) do
    if workspace.active then
      hl.dispatch(hl.dsp.focus({ workspace = workspaces[(index - 1 + delta) % #workspaces + 1] }))
      return
    end
  end
end

return M
