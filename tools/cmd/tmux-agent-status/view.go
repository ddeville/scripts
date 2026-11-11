package main

import (
	"fmt"
	"strings"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"github.com/ddeville/scripts/tools/internal/tui"
)

// Panel widths include borders and padding; rows is the content height.
func (m *model) panelDimensions(which area) (left, right, rows int) {
	width := max(12, m.width-2)

	view := &m.agentView
	if which == worktreesArea {
		view = &m.worktreeView
	}

	rows = max(1, m.height-12)

	if width >= 96 && !view.expanded {
		left = (width - 1) * 3 / 5
		right = width - 1 - left
	} else {
		left = width
	}

	return
}

func panel(title, content string, width, rows int, focused bool) string {
	style := tui.Muted
	if focused {
		style = tui.Yellow
	}

	return lipgloss.NewStyle().Width(width).Height(rows+4).Padding(0, 1).
		Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.BrightBlack).
		Render(style.Render(tui.Fit(title, width-4)) + "\n\n" + content)
}

func detailHeader(title, path, status, action string) []string {
	return []string{
		tui.Title.Render(tui.CleanLine(title)),
		tui.Muted.Render(tui.ShortPath(path)), "",
		status,
		tui.Muted.Render("Enter " + action),
	}
}

func (m *model) listView() string {
	view := m.activeView()
	if view.list.Len() > 0 {
		return view.list.View()
	}

	message := "No conversations match this status"
	if m.area == worktreesArea {
		message = "No managed worktrees yet.\n\nPress n to create your first worktree."
	} else if m.data.At.IsZero() {
		message = "Loading agents…"
	}

	if m.area == agentsArea && m.data.Err != nil {
		message = "Could not read agent status"
	}

	return tui.Muted.Render(clippedLines(message, view.list.Height(), view.list.Width()))
}

func (m *model) panelsView() string {
	left, right, rows := m.panelDimensions(m.area)
	view := m.activeView()
	list := m.listView()
	title := fmt.Sprintf("Agents · %d", view.list.Len())
	detailTitle := "Selected agent"

	if m.area == worktreesArea {
		title = fmt.Sprintf("Worktrees · %d", view.list.Len())
		detailTitle = "Selected worktree"
	}

	if right == 0 {
		if view.detailsFocus {
			title, list = detailTitle, view.details.View()
		}

		return panel(title, list, left, rows, true)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top,
		panel(title, list, left, rows, !view.detailsFocus), " ",
		panel(detailTitle, view.details.View(), right, rows, view.detailsFocus))
}

func (m *model) areaHeading() string {
	tabs := make([]string, 0, 2)

	for _, tab := range []struct {
		area  area
		label string
	}{{agentsArea, " a Agents "}, {worktreesArea, " b Worktrees "}} {
		style := tui.Muted
		if m.area == tab.area {
			style = tui.Yellow.Background(tui.SelectedBackground)
		}

		tabs = append(tabs, style.Render(tab.label))
	}

	return strings.Join(tabs, "  ")
}

func (m *model) toolbar() string {
	if m.area == worktreesArea {
		help := tui.NewHelp(max(12, m.width-2))
		help.Styles.ShortKey = tui.Yellow
		help.Styles.ShortDesc = lipgloss.NewStyle()

		return help.ShortHelpView([]key.Binding{keys.create, keys.remove})
	}

	var tabs []string

	for i, label := range filters {
		label = fmt.Sprintf(" %s %d ", label, len(m.filtered(i)))

		style := tui.Muted
		if i == m.filter {
			style = tui.Yellow.Background(tui.SelectedBackground)
		}

		tabs = append(tabs, style.Render(label))
	}

	return strings.Join(tabs, " ")
}

func (m *model) View() tea.View {
	width := max(12, m.width-2)
	_, _, rows := m.panelDimensions(m.area)

	summary := m.summary()
	if m.area == worktreesArea {
		summary = tui.Muted.Render(tui.ShortPath(m.root))
	}

	toolbar := m.toolbar()
	body := m.panelsView()
	helpView := tui.NewHelp(width)
	footer := helpView.ShortHelpView([]key.Binding{keys.jump, keys.up, keys.down, keys.open, keys.quit})

	controls := []key.Binding{keys.list, keys.details, keys.expand, keys.create}
	if m.area == agentsArea {
		controls = append([]key.Binding{keys.nextFilter, keys.attention}, controls...)
	} else {
		controls = append(controls, keys.remove, keys.refresh)
	}

	help := helpView.ShortHelpView(controls)
	if m.notice != "" {
		help = tui.Muted.Render(tui.CleanLine(m.notice))
	}

	if m.area == agentsArea && m.data.Err != nil {
		help = tui.Red.Render("Agent status unavailable: " + tui.SingleLine(m.data.Err.Error()))
	}

	if m.area == worktreesArea && m.treeError != "" {
		help = tui.Red.Render(tui.SingleLine(m.treeError))
	}

	if m.create != nil {
		summary = "Create from a committed base; local changes stay in the source."
		toolbar = "New worktree"
		title := "New worktree"
		footer = "Enter create · Esc cancel · Tab ↑/↓ fields · Space toggle"

		help = tui.Muted.Render(tui.CleanLine(m.create.message))
		if m.create.picking {
			summary = "Choose a conversation to fork into the new worktree."
			toolbar = "Running conversations, grouped by repository"
			title = "Conversation"
			footer = "j/k ↑/↓ move · Enter choose · Esc back"
			help = tui.Muted.Render("Choose in Codex also lets you browse saved conversations.")
		}

		body = panel(title, m.createView(width-4, rows), width, rows, true)
	} else if m.remove != nil {
		summary = "Review the checkout, branch, and tmux sessions below."
		toolbar = "Remove worktree"

		footer = "y remove · Esc cancel · k keep branch · ↑/↓ scroll"
		if m.remove.keepBranch {
			footer = "y remove · Esc cancel · k delete branch · ↑/↓ scroll"
		}

		help = ""
		if m.remove.checking {
			help = tui.Muted.Render("Checking Git and tmux…")
		}

		if m.remove.err != nil || m.remove.checking {
			footer = "k keep/delete branch · ↑/↓ scroll · Esc cancel"
		}

		body = panel("Remove worktree", m.remove.view.View(), width, rows, true)
	}

	if m.busy {
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
