package codexstatus

import "charm.land/bubbles/v2/key"

var keys = struct {
	up, down, first, last, quit, open, jump key.Binding
	nextFilter, previousFilter, attention   key.Binding
	list, details, expand                   key.Binding
}{
	up:             key.NewBinding(key.WithKeys("k", "up"), key.WithHelp("k/↑", "up")),
	down:           key.NewBinding(key.WithKeys("j", "down"), key.WithHelp("j/↓", "down")),
	first:          key.NewBinding(key.WithKeys("g", "home"), key.WithHelp("g", "first")),
	last:           key.NewBinding(key.WithKeys("G", "end"), key.WithHelp("G", "last")),
	quit:           key.NewBinding(key.WithKeys("q", "esc", "ctrl+c"), key.WithHelp("q", "close")),
	open:           key.NewBinding(key.WithKeys("enter"), key.WithHelp("Enter", "open")),
	jump:           key.NewBinding(key.WithKeys("0", "1", "2", "3", "4", "5", "6", "7", "8", "9"), key.WithHelp("0–9", "jump")),
	nextFilter:     key.NewBinding(key.WithKeys("tab"), key.WithHelp("Tab", "filter")),
	previousFilter: key.NewBinding(key.WithKeys("shift+tab")),
	attention:      key.NewBinding(key.WithKeys("ctrl+f"), key.WithHelp("Ctrl-f", "needs you")),
	list:           key.NewBinding(key.WithKeys("h", "left"), key.WithHelp("h/←", "agents")),
	details:        key.NewBinding(key.WithKeys("l", "right"), key.WithHelp("l/→", "details")),
	expand:         key.NewBinding(key.WithKeys("e"), key.WithHelp("e", "expand")),
}
