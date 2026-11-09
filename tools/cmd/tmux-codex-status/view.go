package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"unicode"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

var (
	muted              = lipgloss.NewStyle().Foreground(lipgloss.BrightBlack)
	yellow             = lipgloss.NewStyle().Foreground(lipgloss.Yellow)
	magenta            = lipgloss.NewStyle().Foreground(lipgloss.Magenta)
	selectedBackground = lipgloss.Color("237")
)

func stateStyle(state string) (lipgloss.Style, string, string) {
	switch state {
	case "approval":
		return lipgloss.NewStyle().Foreground(lipgloss.Red), "Approve", "Waiting for approval. Open the agent to approve or reject."
	case "input":
		return lipgloss.NewStyle().Foreground(lipgloss.Red), "Reply", "Waiting for your answer. Open the agent to reply."
	case "error":
		return magenta, "Check error", "The agent reported an error. Open it to investigate."
	case "ready":
		return lipgloss.NewStyle().Foreground(lipgloss.Green), "Read result", "A completed result is waiting to be read."
	case "working":
		return lipgloss.NewStyle().Foreground(lipgloss.Cyan), "Working", "Working. Open the agent to follow progress or steer it."
	case "idle":
		return muted, "Idle", "Idle. Open the agent to continue the conversation."
	default:
		return muted, "Check status", "Status is unknown. Open the agent to check."
	}
}
func fit(s string, width int) string { return ansi.Truncate(s, max(0, width), "…") }
func pad(s string, width int) string {
	s = fit(s, width)
	return s + strings.Repeat(" ", max(0, width-ansi.StringWidth(s)))
}
func line(s string, width int) string { return pad(s, width) }

func (m model) summary() string {
	counts := map[string]int{}
	for _, a := range m.data.Agents {
		counts[a.State]++
	}

	var parts []string

	for _, state := range []string{"approval", "input", "error", "ready"} {
		if counts[state] > 0 {
			style, label, _ := stateStyle(state)
			parts = append(parts, style.Render(fmt.Sprintf("%s %d", label, counts[state])))
		}
	}

	if len(parts) == 0 {
		return muted.Render("Nothing needs your attention")
	}

	return "Needs you:  " + strings.Join(parts, muted.Render("  ·  "))
}

func (m model) listView(width, height int) string {
	agents := m.filtered(m.filter)
	lines := []string{}

	selected := 0
	for i, a := range agents {
		if a.ID == m.selected {
			selected = i
		}
	}

	capacity := max(1, height/2)

	start := max(0, selected-capacity+1)
	for _, a := range agents[start:min(len(agents), start+capacity)] {
		style, label, _ := stateStyle(a.State)

		base, keyStyle, pathStyle := lipgloss.NewStyle(), yellow, muted
		if a.ID == m.selected {
			base = base.Background(selectedBackground)
			keyStyle = keyStyle.Background(selectedBackground)
			pathStyle = pathStyle.Background(selectedBackground)
			style = style.Background(selectedBackground)
		}

		dot := "●"
		if a.State == "idle" {
			dot = "○"
		}

		number := " "
		if position := m.positions[a.ID]; position < 10 {
			number = string("1234567890"[position])
		}

		titleWidth := max(1, width-20)

		title := strings.Join(strings.Fields(clean(a.Title)), " ")
		if a.ParentID != nil {
			title = "↳ " + title
		}

		row := keyStyle.Render(number+" ") + style.Render(dot+" ") + base.Render(pad(title, titleWidth)+"  ") + style.Render(pad(label, 14))
		project := base.Render("    ") + pathStyle.Render(pad(shortPath(a.Cwd), width-4))
		lines = append(lines, row, project)
	}

	if len(agents) == 0 {
		message := "No conversations match this filter"
		if m.data.At.IsZero() {
			message = "Connecting to Codex…"
		}

		if m.data.Err != nil {
			message = "Could not read Codex status"
		}

		lines = append(lines, muted.Render(fit(message, width)))
	}

	for len(lines) < height {
		lines = append(lines, "")
	}

	return lipgloss.NewStyle().Width(width).Height(height).MaxHeight(height).Render(strings.Join(lines, "\n"))
}

func (m model) detailLines(width int) []string {
	var current *agent

	for _, a := range m.data.Agents {
		if a.ID == m.selected {
			current = &a
			break
		}
	}

	if current == nil {
		return []string{muted.Render("No conversation selected")}
	}

	a := *current
	style, _, hint := stateStyle(a.State)

	var content strings.Builder
	content.WriteString(clean(a.Title) + "\n" + muted.Render(shortPath(a.Cwd)) + "\n\n" + style.Render(hint) + "\n" + muted.Render("Enter to open"))

	if a.Error != nil {
		content.WriteString("\n\n" + magenta.Render(clean(*a.Error)))
	}

	entries := m.activity.Entries
	if len(entries) == 0 {
		entries = []entry{{"Prompt", a.Preview}}
	}

	if m.activity.Err != nil {
		content.WriteString("\n\n" + magenta.Render(clean(m.activity.Err.Error())))
	}

	for _, e := range entries {
		text := []rune(e.Text)
		if len(text) > 6000 {
			text = text[:6000]
		}

		content.WriteString("\n\n" + yellow.Render(e.Label) + "\n" + strings.ReplaceAll(clean(string(text)), "\t", "    "))
	}

	return strings.Split(ansi.Wrap(content.String(), width, ""), "\n")
}

func (m model) detailView(width, height int) string {
	lines := m.detailLines(width)
	offset := min(m.scroll, max(0, len(lines)-height))

	return strings.Join(lines[offset:min(len(lines), offset+height)], "\n")
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
	style := muted
	if focused {
		style = yellow
	}

	return lipgloss.NewStyle().
		Width(width).Height(rows+4).
		Padding(0, 1).
		Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.BrightBlack).
		Render(style.Render(fit(title, width-4)) + "\n\n" + content)
}

func (m model) panelsView() string {
	left, right, rows := m.panelDimensions()
	list := m.listView(left-4, rows)

	if right == 0 {
		title := "Agents · press a number to open"
		if m.detailsFocus {
			title, list = "Selected agent", m.detailView(left-4, rows)
		}

		return panel(title, list, left, rows, true)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top,
		panel("Agents · press a number to open", list, left, rows, !m.detailsFocus),
		" ",
		panel("Selected agent", m.detailView(right-4, rows), right, rows, m.detailsFocus),
	)
}

func (m model) View() tea.View {
	width := max(12, m.width-2)
	title := yellow.Render("Codex agents")

	stamp := "  tmux"
	if !m.data.At.IsZero() {
		stamp += " · updated " + m.data.At.Format("3:04:05 PM")
	}

	heading := title + muted.Render(stamp)

	summary := m.summary()
	if m.data.At.IsZero() {
		summary = muted.Render("Connecting to Codex…")
	}

	tabs := make([]string, 0, len(filters))

	for i, label := range filters {
		label = fmt.Sprintf(" %s %d ", label, len(m.filtered(i)))

		tab := muted.Render(label)
		if i == m.filter {
			tab = yellow.Background(selectedBackground).Render(label)
		}

		tabs = append(tabs, tab)
	}

	footer := muted.Render("1–9/0 jump · j/k move · Enter open · q close")

	help := "Tab filter · Ctrl-f needs you · h/l details · e expand · Ctrl-d/u scroll"
	if m.opening {
		help = "Opening agent…"
	}

	if m.data.Err != nil {
		help = "Status unavailable: " + clean(m.data.Err.Error())
	}

	if m.notice != "" {
		help = m.notice
	}

	content := line(heading, width) + "\n" + line(summary, width) + "\n\n" + line(strings.Join(tabs, " "), width) + "\n" + m.panelsView() + "\n" + line(footer, width) + "\n" + line(muted.Render(help), width)
	view := tea.NewView(lipgloss.NewStyle().Padding(1, 1, 0, 1).Render(content))
	view.AltScreen = true

	return view
}

type activity struct {
	ID      string
	Entries []entry
	Err     error
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
			e = entry{"Codex", item.Text}
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

func clean(s string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsControl(r) && r != '\n' && r != '\t' {
			return -1
		}

		return r
	}, s)
}

func shortPath(path string) string {
	home, _ := os.UserHomeDir()
	if path == home {
		return "~"
	}

	if strings.HasPrefix(path, home+"/") {
		path = "~" + strings.TrimPrefix(path, home)
	}

	return strings.Join(strings.Fields(clean(path)), " ")
}
