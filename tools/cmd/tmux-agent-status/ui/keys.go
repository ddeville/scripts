package ui

import "charm.land/bubbles/v2/key"

var keys = struct {
	quit, open, jump                           key.Binding
	agents, worktrees, create, remove, refresh key.Binding
}{
	quit:      key.NewBinding(key.WithKeys("q", "esc", "ctrl+c"), key.WithHelp("q", "close")),
	open:      key.NewBinding(key.WithKeys("enter"), key.WithHelp("Enter", "open")),
	jump:      key.NewBinding(key.WithKeys("0", "1", "2", "3", "4", "5", "6", "7", "8", "9"), key.WithHelp("0–9", "jump")),
	agents:    key.NewBinding(key.WithKeys("a"), key.WithHelp("a", "agents")),
	worktrees: key.NewBinding(key.WithKeys("b"), key.WithHelp("b", "worktrees")),
	create:    key.NewBinding(key.WithKeys("n"), key.WithHelp("n", "new worktree")),
	remove:    key.NewBinding(key.WithKeys("d"), key.WithHelp("d", "remove")),
	refresh:   key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "refresh")),
}
