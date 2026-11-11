package main

import (
	"fmt"
	"strconv"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func (m *model) renderList() {
	var lines []string

	start, end := 0, 0
	columns := m.columns()

	for position, index := range m.visible {
		item := m.items[index]
		rowStart := len(lines)

		if position == 0 || item.Repo != m.items[m.visible[position-1]].Repo {
			if position > 0 {
				lines = append(lines, "")
			}

			heading := columns
			heading.name += columns.number + 4
			lines = append(lines, heading.line(tui.Blue.Bold(true).Render(tui.CleanLine(item.Repo)),
				tui.Muted.Render("branch"), tui.Muted.Render("git"), tui.Muted.Render("tmux session")))
		}

		if position == m.index {
			start, end = rowStart, len(lines)+1
		}

		lines = append(lines, m.row(item, position, position == m.index, columns))
	}

	if len(lines) == 0 {
		message := "No worktrees match this filter"
		if len(m.items) == 0 {
			message = "No managed worktrees in " + tui.CleanLine(m.root)
		}

		lines = append(lines, tui.Muted.Render(tui.Fit(message, m.view.Width())))
	}

	offset := m.view.YOffset()
	m.view.SetContentLines(lines)
	m.view.SetYOffset(max(end-m.view.Height(), min(offset, start)))
}

type columns struct{ number, name, branch, status, session int }

func (m *model) columns() columns {
	c := columns{number: max(2, len(strconv.Itoa(max(0, len(m.visible)-1)))), name: 8, branch: 6, status: 5}
	for _, item := range m.items {
		c.name = max(c.name, ansi.StringWidth(tui.CleanLine(item.Name)))
		c.branch = max(c.branch, ansi.StringWidth(tui.CleanLine(item.Branch)))
	}

	available := max(0, m.view.Width()-c.number-4)
	if m.view.Width() < 60 {
		c.branch = 0
		c.name = min(c.name, max(1, (available-c.status-4)/2))
		c.session = max(0, available-c.name-c.status-4)
	} else {
		c.name = min(c.name, (available-c.status-6)/3)
		c.branch = min(c.branch, (available-c.status-6)/3)
		c.session = max(0, available-c.name-c.branch-c.status-6)
	}

	return c
}

func (c columns) line(name, branch, status, session string) string {
	parts := []string{tui.Pad(name, c.name)}
	if c.branch > 0 {
		parts = append(parts, tui.Pad(branch, c.branch))
	}

	parts = append(parts, tui.Pad(status, c.status), tui.Pad(session, c.session))

	return strings.Join(parts, "  ")
}

func (m *model) row(item worktree, position int, selected bool, columns columns) string {
	state, stateStyle := item.Status, tui.Muted

	switch item.Status {
	case "clean":
		stateStyle = tui.Green
	case "dirty":
		stateStyle = tui.Yellow
	case "unknown":
		state = "error"
		stateStyle = tui.Red
	default:
		state = "…"
	}

	sessionText := "new session"
	if !m.sessionsReady {
		sessionText = "…"
	} else if item.Session.ID != "" {
		sessionText = tui.CleanLine(item.Session.Name)
	}

	name := tui.CleanLine(item.Name)
	branch := tui.CleanLine(item.Branch)

	if selected {
		line := fmt.Sprintf("▎ %*d  ", columns.number, position) + columns.line(name, branch, state, sessionText)
		return tui.Selected.Render(tui.Pad(line, m.view.Width()))
	}

	return tui.Muted.Render(fmt.Sprintf("  %*d  ", columns.number, position)) +
		columns.line(name, tui.Muted.Render(branch), stateStyle.Render(state), tui.Muted.Render(sessionText))
}

func (m *model) View() tea.View {
	width := max(1, m.width-2)
	heading := lipgloss.NewStyle().Bold(true).Render("Worktrees") + tui.Muted.Render(fmt.Sprintf("  %d / %d", len(m.visible), len(m.items)))
	columns := m.columns()
	selectedPath := ""

	if len(m.visible) > 0 {
		item := m.items[m.visible[m.index]]
		selectedPath = tui.ShortPath(item.Path)

		if columns.branch == 0 {
			selectedPath = tui.CleanLine(item.Branch) + " · " + selectedPath
		}

		if item.StatusError != "" {
			selectedPath += " · " + tui.CleanLine(item.StatusError)
		}
	}

	footer := "0–9 jump · j/k/↑/↓ move · / filter · Enter open · q close"
	if m.filter.Focused() {
		footer = "↑/↓ move · Ctrl-U clear · Enter open · Esc navigation"
	}

	notice := m.notice
	if m.opening {
		notice = "Opening worktree…"
	}

	detail := tui.Muted.Render(tui.Fit(selectedPath, width))
	if notice != "" {
		detail = tui.Red.Render(tui.Fit(tui.CleanLine(notice), width))
	}

	content := strings.Join([]string{
		tui.Fit(heading+"   "+m.filter.View(), width), "", m.view.View(),
		"", detail, tui.Muted.Render(tui.Fit(footer, width)),
	}, "\n")
	view := tea.NewView(tui.Frame.Render(content))
	view.AltScreen = true

	return view
}
