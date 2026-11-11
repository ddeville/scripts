package main

import (
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func worktreeStateStyle(status string) (lipgloss.Style, string, string) {
	switch status {
	case "clean":
		return tui.Muted, "Clean", "Clean working tree"
	case "dirty":
		return tui.Yellow, "Changed", "Changed working tree"
	case "unknown":
		return tui.Red, "Error", "Could not read Git status"
	default:
		return tui.Muted, "…", "Reading Git status…"
	}
}

func (m *model) worktreeDetails(width int) string {
	item, ok := m.selectedWorktree()
	if !ok {
		return tui.Muted.Render("Create a worktree with n.")
	}

	style, _, hint := worktreeStateStyle(item.Status)
	action := "to open"
	session := tui.Muted.Render("Not running")

	switch {
	case !m.sessionsReady:
		session = tui.Muted.Render("Checking sessions…")
	case item.Session.ID != "":
		session = tui.CleanLine(item.Session.Name)
	default:
		action = "to create repo / editor / Codex"
	}

	lines := detailHeader(item.Name, item.Path, style.Render(hint), action)
	lines = append(lines,
		"", tui.Heading.Render("Branch"), tui.CleanLine(item.Branch),
		"", tui.Heading.Render("Tmux session"), session,
		"", tui.Heading.Render("Changes"))

	changes := m.changes[item.Path]
	switch {
	case item.StatusError != "":
		lines = append(lines, tui.Red.Render(tui.CleanLine(item.StatusError)))
	case changes == "":
		text := "No local changes"
		if item.Status != "clean" {
			text = "Reading Git status…"
		}

		lines = append(lines, tui.Muted.Render(text))
	default:
		lines = append(lines, tui.CleanText(changes))
	}

	return ansi.Wrap(strings.Join(lines, "\n"), max(1, width), "")
}
