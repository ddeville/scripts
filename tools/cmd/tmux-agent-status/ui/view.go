package ui

import (
	"strings"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	agentui "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/agents"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/internal/tui"
)

func (m *model) areaHeading() string {
	tabs := make([]string, 0, 2)

	for _, tab := range []struct {
		area  Area
		label string
	}{{AgentsArea, " a Agents "}, {WorktreesArea, " b Worktrees "}} {
		style := tui.Muted
		if m.area == tab.area {
			style = tui.Yellow.Background(tui.SelectedBackground)
		}

		tabs = append(tabs, style.Render(tab.label))
	}

	return strings.Join(tabs, "  ")
}

func (m *model) toolbar() string {
	if m.area == WorktreesArea {
		help := tui.NewHelp(max(12, m.width-2))
		help.Styles.ShortKey = tui.Yellow
		help.Styles.ShortDesc = lipgloss.NewStyle()

		return help.ShortHelpView([]key.Binding{keys.create, keys.remove})
	}

	return m.agents.Toolbar()
}

func (m *model) View() tea.View {
	width := max(12, m.width-2)

	summary, body, message := m.agents.Summary(), m.agents.View(), m.agents.Message(m.notice)
	if m.area == WorktreesArea {
		summary, body, message = m.worktrees.Summary(), m.worktrees.View(), m.worktrees.Message(m.notice)
	}

	toolbar := m.toolbar()
	helpView := tui.NewHelp(width)
	footer := helpView.ShortHelpView([]key.Binding{keys.jump, panel.Keys.Up, panel.Keys.Down, keys.open, keys.quit})

	controls := []key.Binding{panel.Keys.List, panel.Keys.Details, panel.Keys.Expand, keys.create}
	if m.area == AgentsArea {
		controls = append([]key.Binding{agentui.Keys.NextFilter, agentui.Keys.Attention}, controls...)
	} else {
		controls = append(controls, keys.remove, keys.refresh)
	}

	help := helpView.ShortHelpView(controls)
	if message != "" {
		help = message
	}

	if form, ok := m.worktrees.Form(); ok {
		summary, toolbar, body, footer, help = form.Summary, form.Toolbar, form.Body, form.Footer, form.Help
	}

	if m.busy() {
		footer = "Working…"
		if m.quitting {
			footer = "Cancelling…"
		}
	}

	content := strings.Join([]string{tui.Pad(m.areaHeading(), width), "", tui.Pad(summary, width), "", tui.Pad(toolbar, width), body, tui.Pad(tui.Muted.Render(tui.CleanLine(footer)), width), tui.Pad(help, width)}, "\n")
	view := tea.NewView(tui.Frame.Render(content))
	view.AltScreen = true

	return view
}
