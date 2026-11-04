local M = {}

-- Monitor order determines the consecutive workspace IDs.
local layouts = {
  default = {
    { names = { 'web', 'code', 'media', 'flt', 'a', 'b', 'c' } },
  },
  arch = {
    { monitor = 'DP-1', names = { 'web', 'media', 'flt', 'a', 'b', 'c' } },
    { monitor = 'DP-2', names = { 'code', 'a', 'b', 'c' } },
  },
}

local floating_names = { flt = true }

function M.setup(hostname)
  local workspaces = {}
  local floating = {}

  for _, group in ipairs(layouts[hostname] or layouts.default) do
    for index, name in ipairs(group.names) do
      local id = #workspaces + 1
      local workspace = {
        workspace = tostring(id),
        monitor = group.monitor,
        default = index == 1,
        default_name = name,
        persistent = true, -- Keep empty workspaces available in the bar and shortcuts.
      }
      workspaces[id] = workspace
      hl.workspace_rule(workspace)
      if floating_names[name] then
        floating[id] = true
        hl.window_rule({ match = { workspace = tostring(id) }, float = true })
      end
    end
  end

  -- The opening rules cover new windows; also float windows moved into these workspaces.
  hl.on('window.move_to_workspace', function(window, workspace)
    if floating[workspace.id] then
      hl.dispatch(hl.dsp.window.float({ window = window, action = 'enable' }))
    end
  end)

  return workspaces
end

return M
