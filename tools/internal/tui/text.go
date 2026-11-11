// Package tui provides text and styling helpers for terminal interfaces.
package tui

import (
	"os"
	"path/filepath"
	"strings"
	"unicode"

	"github.com/charmbracelet/x/ansi"
)

// CleanText strips ANSI sequences and controls, preserving newlines and tabs.
func CleanText(text string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsControl(r) && r != '\n' && r != '\t' {
			return -1
		}

		return r
	}, ansi.Strip(text))
}

// CleanLine strips ANSI sequences and replaces controls with spaces without collapsing whitespace.
func CleanLine(text string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return ' '
		}

		return r
	}, ansi.Strip(text))
}

// SingleLine cleans text and collapses whitespace for compact labels and previews.
func SingleLine(text string) string {
	return strings.Join(strings.Fields(CleanText(text)), " ")
}

// Fit truncates a styled line to a terminal-cell width, adding an ellipsis when needed.
func Fit(text string, width int) string {
	return ansi.Truncate(text, max(0, width), "…")
}

// Pad fits a styled line and pads it to a terminal-cell width.
func Pad(text string, width int) string {
	text = Fit(text, width)
	return text + strings.Repeat(" ", max(0, width-ansi.StringWidth(text)))
}

// ShortPath abbreviates the user's home directory and cleans the path for one-line display.
func ShortPath(path string) string {
	if home, err := os.UserHomeDir(); err == nil {
		if path == home {
			path = "~"
		} else if relative, ok := strings.CutPrefix(path, home+string(filepath.Separator)); ok {
			path = "~/" + relative
		}
	}

	return CleanLine(path)
}
