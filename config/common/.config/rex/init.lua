-- TODO: Move themes, font, spacing, cursor, UI styling, and agent naming here when Lua settings are available.
-- TODO: Add native tab numbers, last-session switching, and cross-session pane moves when supported.

rex.bind('ctrl+a>ctrl+a', 'pane.send_key', { key = 'ctrl+a' })

-- Sessions group projects; tabs are the equivalent of tmux windows.
rex.bind('ctrl+a>shift+c', 'session.new')
rex.bind('ctrl+a>shift+4', 'session.rename')
rex.bind('ctrl+a>g', 'session.switch')
rex.bind('ctrl+a>space', 'session.switch')
rex.bind('ctrl+a>w', 'pane.go_to')

rex.bind('ctrl+a>c', 'client.tab.new')
rex.bind('ctrl+a>n', 'client.tab.next')
rex.bind('ctrl+a>p', 'client.tab.previous')
rex.bind('ctrl+a>,', 'client.tab.rename')
for index = 1, 9 do
  rex.bind('ctrl+a>' .. index, 'client.tab.goto', { index = index })
end

rex.bind('ctrl+a>s', 'pane.split', { direction = 'right' })
rex.bind('ctrl+a>v', 'pane.split', { direction = 'down' })
rex.bind('ctrl+a>h', 'pane.focus', { direction = 'left' })
rex.bind('ctrl+a>j', 'pane.focus', { direction = 'down' })
rex.bind('ctrl+a>k', 'pane.focus', { direction = 'up' })
rex.bind('ctrl+a>l', 'pane.focus', { direction = 'right' })
rex.bind('ctrl+a>z', 'pane.zoom')
rex.bind('ctrl+a>shift+1', 'pane.move_to_new_tab')

rex.bind('ctrl+a>r', 'client.config.reload')
rex.mode('resize', { exclusive = true })
rex.bind('ctrl+a>shift+r', 'client.mode.enter', { name = 'resize' })
rex.bind('resize/enter', 'client.mode.exit')
rex.bind('resize/escape', 'client.mode.exit')

-- Rex measures resize amounts as percentages, rather than tmux's cells.
rex.bind('ctrl+a>shift+h', 'pane.resize', { amount = 2, direction = 'left' })
rex.bind('resize/shift+h', 'pane.resize', { amount = 2, direction = 'left' })
rex.bind('ctrl+a>shift+j', 'pane.resize', { amount = 2, direction = 'down' })
rex.bind('resize/shift+j', 'pane.resize', { amount = 2, direction = 'down' })
rex.bind('ctrl+a>shift+k', 'pane.resize', { amount = 2, direction = 'up' })
rex.bind('resize/shift+k', 'pane.resize', { amount = 2, direction = 'up' })
rex.bind('ctrl+a>shift+l', 'pane.resize', { amount = 2, direction = 'right' })
rex.bind('resize/shift+l', 'pane.resize', { amount = 2, direction = 'right' })
