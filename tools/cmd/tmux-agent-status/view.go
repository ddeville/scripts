package main

import (
	"encoding/json"
	"fmt"
	"slices"
	"strings"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func stateStyle(state string) (lipgloss.Style, string, string) {
	switch state {
	case "approval":
		return tui.Red, "Approve", "Waiting for approval. Open the agent to approve or reject."
	case "input":
		return tui.Red, "Reply", "Waiting for your answer. Open the agent to reply."
	case "error":
		return tui.Magenta, "Check error", "The agent reported an error. Open it to investigate."
	case "ready":
		return tui.Green, "Read result", "A completed result is waiting to be read."
	case "working":
		return tui.Cyan, "Working", "Working. Open the agent to follow progress or steer it."
	case "idle":
		return lipgloss.NewStyle(), "Idle", "Idle. Open the agent to continue the conversation."
	default:
		return tui.Muted, "Check status", "Status is unknown. Open the agent to check."
	}
}

func (m model) summary() string {
	if m.data.Err != nil {
		if m.data.At.IsZero() {
			return tui.Magenta.Render("Agent status unavailable")
		}

		return tui.Magenta.Render("Status unavailable · showing last known data")
	}

	if m.data.At.IsZero() {
		return tui.Muted.Render("Loading agents…")
	}

	var parts []string

	for _, state := range []string{"approval", "input", "error", "ready"} {
		if count := m.data.Counts[state]; count > 0 {
			style, label, _ := stateStyle(state)
			parts = append(parts, style.Render(fmt.Sprintf("%s %d", label, count)))
		}
	}

	if len(parts) == 0 {
		return tui.Muted.Render("Nothing needs your attention")
	}

	return "Needs you:  " + strings.Join(parts, tui.Muted.Render("  ·  "))
}

func (m model) listView() string {
	if len(m.agents.items) == 0 {
		message := "No conversations match this filter"
		if m.data.At.IsZero() {
			message = "Loading agents…"
		}

		if m.data.Err != nil {
			message = "Could not read agent status"
		}

		return tui.Muted.Render(tui.Fit(message, m.agents.view.Width()))
	}

	return m.agents.view.View()
}

func (m model) detailContent(width int) string {
	index := slices.IndexFunc(m.data.Agents, func(a agent) bool { return a.ID == m.selected })
	if index < 0 {
		return tui.Muted.Render("No conversation selected")
	}

	a := m.data.Agents[index]
	style, _, hint := stateStyle(a.State)

	lines := []string{
		tui.Yellow.Bold(true).Render(tui.CleanText(a.Title)),
		tui.Blue.Render(tui.ShortPath(a.Cwd)),
		"",
		style.Render(hint),
		tui.Yellow.Render("Enter") + tui.Muted.Render(" to open"),
	}

	if a.Error != nil {
		lines = append(lines, "", tui.Magenta.Render(tui.CleanText(*a.Error)))
	}

	entries := m.activity.Entries
	if len(entries) == 0 {
		entries = []entry{{"Prompt", a.Preview}}
	}

	if m.activity.Err != nil {
		lines = append(lines, "", tui.Magenta.Render(tui.CleanText(m.activity.Err.Error())))
	}

	for _, e := range entries {
		text := []rune(e.Text)
		if len(text) > 6000 {
			text = text[:6000]
		}

		lines = append(lines, "", entryStyle(e.Label).Bold(true).Render(e.Label),
			strings.ReplaceAll(tui.CleanText(string(text)), "\t", "    "))
	}

	return ansi.Wrap(strings.Join(lines, "\n"), width, "")
}

func entryStyle(label string) lipgloss.Style {
	switch label {
	case "Prompt":
		return tui.Blue
	case "Agent":
		return tui.Cyan
	case "Command", "Tool":
		return tui.Yellow
	case "Error":
		return tui.Magenta
	default:
		return tui.Muted
	}
}

// Panel widths include borders and padding; rows is the content height.
func (m model) panelDimensions() (left, right, rows int) {
	width := max(12, m.width-2)

	rows = max(1, m.height-11)
	if width >= 96 && !m.expanded {
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

	return lipgloss.NewStyle().
		Width(width).Height(rows+4).
		Padding(0, 1).
		Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.BrightBlack).
		Render(style.Render(tui.Fit(title, width-4)) + "\n\n" + content)
}

func (m model) panelsView() string {
	left, right, rows := m.panelDimensions()
	list := m.listView()
	title := fmt.Sprintf("Threads · %d", len(m.agents.items))

	if right == 0 {
		if m.detailsFocus {
			title, list = "Selected agent", m.details.View()
		}

		return panel(title, list, left, rows, true)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top,
		panel(title, list, left, rows, !m.detailsFocus),
		" ",
		panel("Selected agent", m.details.View(), right, rows, m.detailsFocus),
	)
}

func (m model) View() tea.View {
	width := max(12, m.width-2)
	title := tui.Yellow.Render("Agents")

	stamp := "  tmux"
	if !m.data.At.IsZero() {
		stamp += " · updated " + m.data.At.Format("3:04:05 PM")
	}

	heading := title + tui.Muted.Render(stamp)

	summary := m.summary()

	tabs := make([]string, 0, len(filters))

	for i, label := range filters {
		label = fmt.Sprintf(" %s %d ", label, len(m.filtered(i)))

		tab := tui.Muted.Render(label)
		if i == m.filter {
			tab = tui.Yellow.Background(tui.SelectedBackground).Render(label)
		}

		tabs = append(tabs, tab)
	}

	helpView := tui.NewHelp(width)
	footer := helpView.ShortHelpView([]key.Binding{keys.jump, keys.up, keys.down, keys.open, keys.quit})

	help := helpView.ShortHelpView([]key.Binding{keys.nextFilter, keys.attention, keys.list, keys.details, keys.expand})
	if m.opening {
		help = "Opening agent…"
	}

	if m.notice != "" {
		help = m.notice
	}

	if m.data.Err != nil {
		help = "Status unavailable: " + tui.SingleLine(m.data.Err.Error())
	}

	content := strings.Join([]string{
		tui.Pad(heading, width),
		tui.Pad(summary, width),
		"",
		tui.Pad(strings.Join(tabs, " "), width),
		m.panelsView(),
		tui.Pad(footer, width),
		tui.Pad(tui.Muted.Render(help), width),
	}, "\n")
	view := tea.NewView(tui.Frame.Render(content))
	view.AltScreen = true

	return view
}

type activity struct {
	ID         string
	generation uint64
	Entries    []entry
	Err        error
}

type entry struct{ Label, Text string }

func activityEntries(data threadDetails) []entry {
	var entries []entry
	if data.HistoryError != nil {
		entries = append(entries, entry{"Error", *data.HistoryError})
	}

	var turn struct {
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if json.Unmarshal(data.LatestTurn, &turn) == nil && turn.Error != nil {
		entries = append(entries, entry{"Error", turn.Error.Message})
	}

	for _, raw := range data.RecentItems {
		var row struct {
			Item struct {
				Type    string `json:"type"`
				Text    string `json:"text"`
				Command string `json:"command"`
				Server  string `json:"server"`
				Tool    string `json:"tool"`
				Content []struct {
					Type string `json:"type"`
					Text string `json:"text"`
				} `json:"content"`
			} `json:"item"`
		}
		if json.Unmarshal(raw, &row) != nil {
			continue
		}

		item := row.Item
		e := entry{}

		switch item.Type {
		case "agentMessage":
			e = entry{"Agent", item.Text}
		case "userMessage":
			e.Label = "Prompt"

			for _, part := range item.Content {
				if part.Type == "text" {
					e.Text += part.Text + "\n"
				}
			}
		case "commandExecution":
			e = entry{"Command", item.Command}
		case "mcpToolCall":
			e = entry{"Tool", item.Server + " / " + item.Tool}
		}

		if e.Text != "" {
			entries = append(entries, e)
		}

		if len(entries) >= 3 {
			break
		}
	}

	return entries
}
