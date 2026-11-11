package agents

import "charm.land/bubbles/v2/key"

// Keys defines filter shortcuts for the section and the app's help text.
var Keys = struct {
	NextFilter, PreviousFilter, Attention key.Binding
}{
	NextFilter:     key.NewBinding(key.WithKeys("tab"), key.WithHelp("Tab", "filter")),
	PreviousFilter: key.NewBinding(key.WithKeys("shift+tab")),
	Attention:      key.NewBinding(key.WithKeys("ctrl+f"), key.WithHelp("Ctrl-f", "needs you")),
}
