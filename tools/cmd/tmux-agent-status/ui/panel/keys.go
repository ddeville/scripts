package panel

import "charm.land/bubbles/v2/key"

// Keys defines navigation shortcuts for both the panel and the app's help text.
var Keys = struct {
	Up, Down, First, Last, List, Details, Expand key.Binding
}{
	Up:      key.NewBinding(key.WithKeys("k", "up"), key.WithHelp("k/↑", "up")),
	Down:    key.NewBinding(key.WithKeys("j", "down"), key.WithHelp("j/↓", "down")),
	First:   key.NewBinding(key.WithKeys("g", "home")),
	Last:    key.NewBinding(key.WithKeys("G", "end")),
	List:    key.NewBinding(key.WithKeys("h", "left"), key.WithHelp("h/←", "list")),
	Details: key.NewBinding(key.WithKeys("l", "right"), key.WithHelp("l/→", "details")),
	Expand:  key.NewBinding(key.WithKeys("e"), key.WithHelp("e", "expand")),
}
