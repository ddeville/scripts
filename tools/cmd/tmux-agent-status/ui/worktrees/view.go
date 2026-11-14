package worktrees

import (
	"fmt"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	agentui "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/agents"
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

	if item.Note != "" {
		lines = append(lines, "", tui.Heading.Render("Note"), tui.CleanText(item.Note))
	}

	var summary []string
	for _, span := range m.agentSummary(item.Path) {
		summary = append(summary, span.Style.Render(span.Text))
	}

	lines = append(lines,
		"", tui.Heading.Render("Branch"), tui.CleanLine(item.Branch),
		"", tui.Heading.Render("Tmux session"), session,
		"", tui.Heading.Render("Agents"), strings.Join(summary, tui.Muted.Render(" · ")))

	for _, a := range agents.InDirectory(m.data.Agents, item.Path) {
		row := agentui.Row(a)
		lines = append(lines, row.StatusStyle.Render(tui.CleanLine(row.Status))+" · "+tui.CleanLine(row.Title))
	}

	lines = append(lines, "", tui.Heading.Render("Changes"))

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

func (m *Model) agentSummary(path string) []tui.TextSpan {
	if m.data.Err != nil {
		return []tui.TextSpan{{Text: "Agent status unavailable", Style: tui.Red}}
	}

	if m.data.At.IsZero() {
		return []tui.TextSpan{{Text: "Loading agents…", Style: tui.Muted}}
	}

	counts := map[string]int{}

	for _, a := range agents.InDirectory(m.data.Agents, path) {
		state := "unknown"

		switch a.State {
		case "approval", "input":
			state = "needs you"
		case "error", "ready", "working", "idle":
			state = a.State
		}

		counts[state]++
	}

	var parts []tui.TextSpan

	for _, state := range []tui.TextSpan{
		{Text: "error", Style: tui.Red.Bold(true)},
		{Text: "needs you", Style: tui.Yellow.Bold(true)},
		{Text: "ready", Style: tui.Green},
		{Text: "working", Style: tui.Cyan},
		{Text: "unknown", Style: tui.Muted},
		{Text: "idle", Style: tui.Muted},
	} {
		if count := counts[state.Text]; count > 0 {
			label := state.Text
			if label == "error" && count > 1 {
				label = "errors"
			}

			parts = append(parts, tui.TextSpan{Text: fmt.Sprintf("%d %s", count, label), Style: state.Style})
		}
	}

	if len(parts) == 0 {
		return []tui.TextSpan{{Text: "No running agents", Style: tui.Muted}}
	}

	return parts
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
