package worktrees

import (
	"fmt"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
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

func (m *Model) worktreeDetails(width int) string {
	item, ok := m.Selected()
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

	lines := panel.DetailHeader(item.Name, item.Path, style.Render(hint), action)
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

// View renders managed checkouts and the selected worktree's details.
func (m *Model) View() string {
	return m.Panel.View(fmt.Sprintf("Worktrees · %d", m.Panel.List.Len()), "Selected worktree", "No managed worktrees yet.\n\nPress n to create your first worktree.")
}

// Summary shows the managed worktree directory.
func (m *Model) Summary() string { return tui.Muted.Render(tui.ShortPath(m.root)) }

// Message renders discovery errors or operation notices for the app footer.
func (m *Model) Message(notice string) string {
	if m.treeError != "" {
		return tui.Red.Render(tui.SingleLine(m.treeError))
	}

	if notice == "" {
		notice = m.notice
	}

	if notice != "" {
		return tui.Muted.Render(tui.CleanLine(notice))
	}

	return ""
}
