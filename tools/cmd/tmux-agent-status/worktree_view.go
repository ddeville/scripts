package main

import (
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func worktreeStateStyle(status string) (string, lipgloss.Style) {
	switch status {
	case "clean":
		return "Clean", tui.Green
	case "dirty":
		return "Changed", tui.Yellow
	case "unknown":
		return "Error", tui.Red
	default:
		return "…", tui.Muted
	}
}

func (m *model) worktreeDetails(width int) string {
	item, ok := m.selectedWorktree()
	if !ok {
		return tui.Muted.Render("Create a worktree with n.")
	}

	state, style := worktreeStateStyle(item.Status)
	lines := []string{
		tui.Yellow.Bold(true).Render(tui.CleanLine(item.Name)),
		tui.Blue.Render(tui.ShortPath(item.Path)), "",
		style.Render(state) + tui.Muted.Render(" working tree"),
		tui.Muted.Render("Branch  ") + tui.CleanLine(item.Branch), "",
		tui.Muted.Render("TMUX SESSION"),
	}

	session := "Enter creates repo / editor / Codex"
	if !m.sessionsReady {
		session = "Checking sessions…"
	} else if item.Session.ID != "" {
		session = tui.CleanLine(item.Session.Name)
	}

	lines = append(lines, session, "", tui.Muted.Render("CHANGES"))

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
