// Package panel provides the shared list-and-details layout for both UI sections.
package panel

import (
	"strings"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"github.com/ddeville/scripts/tools/internal/tui"
)

// Model holds the section's navigation widgets and layout state.
type Model struct {
	List    tui.List
	Details viewport.Model

	detailsFocus, expanded bool
	width, rows            int
}

// New creates a section with independent selection, scrolling, and focus.
func New() Model { return Model{List: tui.NewList(), Details: NewViewport()} }

// NewViewport uses the same scrolling keys for details and removal previews.
func NewViewport() viewport.Model {
	view := viewport.New()
	view.KeyMap = viewport.KeyMap{Up: Keys.Up, Down: Keys.Down}
	view.MouseWheelEnabled = false

	return view
}

// SetSize assigns the available panel width and content rows.
func (m *Model) SetSize(width, rows int) {
	m.width, m.rows = width, rows
	left, right := m.dimensions()
	m.List.SetSize(left-4, rows)

	if right > 0 {
		left = right
	}

	m.Details.SetWidth(max(1, left-4))
	m.Details.SetHeight(rows)
}

func (m *Model) dimensions() (left, right int) {
	if m.width >= 96 && !m.expanded {
		left = (m.width - 1) * 3 / 5
		right = m.width - 1 - left
	} else {
		left = m.width
	}

	return
}

// Update handles focus, expansion, and navigation within the active section.
func (m *Model) Update(msg tea.KeyPressMsg) tea.Cmd {
	switch {
	case key.Matches(msg, Keys.List):
		m.detailsFocus, m.expanded = false, false
	case key.Matches(msg, Keys.Details):
		m.detailsFocus = true
	case key.Matches(msg, Keys.Expand):
		m.expanded = !m.expanded
		m.detailsFocus = m.expanded
	default:
		if m.detailsFocus {
			var cmd tea.Cmd

			switch {
			case key.Matches(msg, Keys.First):
				m.Details.GotoTop()
			case key.Matches(msg, Keys.Last):
				m.Details.GotoBottom()
			default:
				m.Details, cmd = m.Details.Update(msg)
			}

			return cmd
		}

		before := m.List.SelectedID()
		m.List.Move(msg)

		if before != m.List.SelectedID() {
			m.Details.GotoTop()
		}
	}

	m.SetSize(m.width, m.rows)

	return nil
}

// View renders the list and details using the shared responsive layout.
func (m *Model) View(title, detailTitle, empty string) string {
	left, right := m.dimensions()

	list := m.List.View()
	if m.List.Len() == 0 {
		list = tui.Muted.Render(ClipLines(empty, m.List.Height(), m.List.Width()))
	}

	if right == 0 {
		if m.detailsFocus {
			title, list = detailTitle, m.Details.View()
		}

		return Render(title, list, left, m.rows, true)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top,
		Render(title, list, left, m.rows, !m.detailsFocus), " ",
		Render(detailTitle, m.Details.View(), right, m.rows, m.detailsFocus))
}

// Render frames section content or a full-width form.
func Render(title, content string, width, rows int, focused bool) string {
	style := tui.Muted
	if focused {
		style = tui.Yellow
	}

	return lipgloss.NewStyle().Width(width).Height(rows+4).Padding(0, 1).
		Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.BrightBlack).
		Render(style.Render(tui.Fit(title, width-4)) + "\n\n" + content)
}

// DetailHeader gives both sections the same title, path, status, and action layout.
func DetailHeader(title, path, status, action string) []string {
	return []string{
		tui.Title.Render(tui.CleanLine(title)),
		tui.Muted.Render(tui.ShortPath(path)), "",
		status,
		tui.Muted.Render("Enter " + action),
	}
}

// ClipLines fits multiline content into the available rows and columns.
func ClipLines(text string, height, width int) string {
	lines := strings.Split(text, "\n")
	if len(lines) > height {
		lines = lines[:height]
		if height > 1 {
			lines[height-1] = tui.Muted.Render("…")
		}
	}

	for i := range lines {
		lines[i] = tui.Fit(lines[i], width)
	}

	return strings.Join(lines, "\n")
}
