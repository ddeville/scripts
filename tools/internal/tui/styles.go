package tui

import (
	"charm.land/bubbles/v2/help"
	"charm.land/lipgloss/v2"
)

// Shared styles use the terminal's palette. Lip Gloss style methods return modified copies.
var (
	Muted   = lipgloss.NewStyle().Foreground(lipgloss.BrightBlack)
	Yellow  = lipgloss.NewStyle().Foreground(lipgloss.Yellow)
	Blue    = lipgloss.NewStyle().Foreground(lipgloss.Blue)
	Green   = lipgloss.NewStyle().Foreground(lipgloss.Green)
	Red     = lipgloss.NewStyle().Foreground(lipgloss.Red)
	Cyan    = lipgloss.NewStyle().Foreground(lipgloss.Cyan)
	Magenta = lipgloss.NewStyle().Foreground(lipgloss.Magenta)

	SelectedBackground = lipgloss.Color("237")
	Selected           = lipgloss.NewStyle().Background(SelectedBackground)
	Frame              = lipgloss.NewStyle().Padding(1, 1, 0, 1)
)

// NewHelp creates a help view with the shared muted styling and separators.
func NewHelp(width int) help.Model {
	model := help.New()
	model.SetWidth(width)
	model.ShortSeparator = " · "
	model.Styles = help.Styles{ShortKey: Muted, ShortDesc: Muted, ShortSeparator: Muted, Ellipsis: Muted}

	return model
}
