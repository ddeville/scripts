package tui

import (
	"fmt"
	"strings"

	"charm.land/bubbles/v2/help"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
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

// SectionHeading renders a label and item count followed by a horizontal rule.
func SectionHeading(label string, count, width int) string {
	countText := fmt.Sprintf("  %d  ", count)
	label = Fit(CleanLine(label), max(0, width-len(countText)-5))

	heading := " " + Blue.Bold(true).Render(label) + Muted.Render(countText)
	rule := strings.Repeat("─", max(0, width-ansi.StringWidth(heading)-1))

	return Fit(heading+Muted.Render(rule), width)
}
