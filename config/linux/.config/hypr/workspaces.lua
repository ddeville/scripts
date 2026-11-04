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
  local floating = {}
  local id = 0
  for _, group in ipairs(layouts[hostname] or layouts.default) do
    for index, name in ipairs(group.names) do
      id = id + 1
      hl.workspace_rule({
        workspace = tostring(id),
        monitor = group.monitor,
        default = index == 1,
        default_name = name,
        persistent = true, -- Keep empty workspaces available in the bar and shortcuts.
      })
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
end

return M
