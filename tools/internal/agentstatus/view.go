package agentstatus

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"
	"unicode"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

var (
	muted              = lipgloss.NewStyle().Foreground(lipgloss.BrightBlack)
	yellow             = lipgloss.NewStyle().Foreground(lipgloss.Yellow)
	blue               = lipgloss.NewStyle().Foreground(lipgloss.Blue)
	cyan               = lipgloss.NewStyle().Foreground(lipgloss.Cyan)
	magenta            = lipgloss.NewStyle().Foreground(lipgloss.Magenta)
	selectedBackground = lipgloss.Color("237")
)

func (t AgentType) label() string {
	switch t {
	case AgentTypeCodex:
		return "Codex"
	case AgentTypeClaude:
		return "Claude"
	default:
		return "Unknown"
	}
}

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

func (m model) summary() string {
	if m.data.Err != nil {
		if m.data.At.IsZero() {
			return magenta.Render("Agent status unavailable")
		}

		return magenta.Render("Status unavailable · showing last known data")
	}

	if m.data.At.IsZero() {
		return muted.Render("Loading agents…")
	}

	var parts []string

	for _, state := range []string{"approval", "input", "error", "ready"} {
		if count := m.data.Counts[state]; count > 0 {
			style, label, _ := stateStyle(state)
			parts = append(parts, style.Render(fmt.Sprintf("%s %d", label, count)))
		}
	}

	if len(parts) == 0 {
		return muted.Render("Nothing needs your attention")
	}

	return "Needs you:  " + strings.Join(parts, muted.Render("  ·  "))
}

type agentItem struct {
	agent

	position int
}

func (a agentItem) FilterValue() string { return a.Title }

type agentDelegate struct{}

func (agentDelegate) Height() int { return 2 }

func (agentDelegate) Spacing() int { return 0 }

func (agentDelegate) Update(tea.Msg, *list.Model) tea.Cmd { return nil }

func newAgentList() list.Model {
	agents := list.New(nil, agentDelegate{}, 0, 0)
	agents.SetShowTitle(false)
	agents.SetShowStatusBar(false)
	agents.SetShowHelp(false)
	agents.SetShowPagination(false)
	agents.SetFilteringEnabled(false)
	agents.InfiniteScrolling = true
	agents.KeyMap = list.KeyMap{
		CursorUp: keys.up, CursorDown: keys.down,
		GoToStart: keys.first, GoToEnd: keys.last,
	}

	return agents
}

func (agentDelegate) Render(w io.Writer, model list.Model, index int, item list.Item) {
	a, ok := item.(agentItem)
	if !ok {
		return
	}

	width := model.Width()
	style, label, _ := stateStyle(a.State)

	base, keyStyle, pathStyle := lipgloss.NewStyle(), yellow, muted
	if index == model.Index() {
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
	if a.position < 10 {
		number = string("0123456789"[a.position])
	}

	titleWidth := max(1, width-20)

	title := singleLine(a.Title)
	if a.ParentID != nil {
		title = "↳ " + title
	}

	prefix := keyStyle.Render(number+" ") + style.Render(dot+" ")
	name := style.Render(pad(title, titleWidth) + "  ")
	status := style.Render(pad(label, 14))
	metadata := a.Type.label() + " · " + shortPath(a.Cwd)
	project := base.Render("    ") + pathStyle.Render(pad(metadata, width-4))
	_, _ = fmt.Fprint(w, fit(prefix+name+status, width), "\n", fit(project, width))
}

func (m model) listView() string {
	if len(m.agents.Items()) == 0 {
		message := "No conversations match this filter"
		if m.data.At.IsZero() {
			message = "Loading agents…"
		}

		if m.data.Err != nil {
			message = "Could not read agent status"
		}

		return muted.Render(fit(message, m.agents.Width()))
	}

	return m.agents.View()
}

func (m model) detailContent(width int) string {
	index := slices.IndexFunc(m.data.Agents, func(a agent) bool { return a.ID == m.selected })
	if index < 0 {
		return muted.Render("No conversation selected")
	}

	a := m.data.Agents[index]
	style, _, hint := stateStyle(a.State)

	lines := []string{
		yellow.Bold(true).Render(CleanText(a.Title)),
		blue.Render(shortPath(a.Cwd)),
		"",
		style.Render(hint),
		yellow.Render("Enter") + muted.Render(" to open"),
	}

	if a.Error != nil {
		lines = append(lines, "", magenta.Render(CleanText(*a.Error)))
	}

	entries := m.activity.Entries
	if len(entries) == 0 {
		entries = []entry{{"Prompt", a.Preview}}
	}

	if m.activity.Err != nil {
		lines = append(lines, "", magenta.Render(CleanText(m.activity.Err.Error())))
	}

	for _, e := range entries {
		text := []rune(e.Text)
		if len(text) > 6000 {
			text = text[:6000]
		}

		lines = append(lines, "", entryStyle(e.Label).Bold(true).Render(e.Label),
			strings.ReplaceAll(CleanText(string(text)), "\t", "    "))
	}

	return ansi.Wrap(strings.Join(lines, "\n"), width, "")
}

func entryStyle(label string) lipgloss.Style {
	switch label {
	case "Prompt":
		return blue
	case "Agent":
		return cyan
	case "Command", "Tool":
		return yellow
	case "Error":
		return magenta
	default:
		return muted
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
	list := m.listView()

	if right == 0 {
		title := "Agents · press a number to open"
		if m.detailsFocus {
			title, list = "Selected agent", m.details.View()
		}

		return panel(title, list, left, rows, true)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top,
		panel("Agents · press a number to open", list, left, rows, !m.detailsFocus),
		" ",
		panel("Selected agent", m.details.View(), right, rows, m.detailsFocus),
	)
}

func (m model) View() tea.View {
	width := max(12, m.width-2)
	title := yellow.Render("Agents")

	stamp := "  tmux"
	if !m.data.At.IsZero() {
		stamp += " · updated " + m.data.At.Format("3:04:05 PM")
	}

	heading := title + muted.Render(stamp)

	summary := m.summary()

	tabs := make([]string, 0, len(filters))

	for i, label := range filters {
		label = fmt.Sprintf(" %s %d ", label, len(m.filtered(i)))

		tab := muted.Render(label)
		if i == m.filter {
			tab = yellow.Background(selectedBackground).Render(label)
		}

		tabs = append(tabs, tab)
	}

	helpView := help.New()
	helpView.SetWidth(width)
	helpView.ShortSeparator = " · "
	helpView.Styles = help.Styles{ShortKey: muted, ShortDesc: muted, ShortSeparator: muted, Ellipsis: muted}
	footer := helpView.ShortHelpView([]key.Binding{keys.jump, keys.up, keys.down, keys.open, keys.quit})

	help := helpView.ShortHelpView([]key.Binding{keys.nextFilter, keys.attention, keys.list, keys.details, keys.expand})
	if m.opening {
		help = "Opening agent…"
	}

	if m.notice != "" {
		help = m.notice
	}

	if m.data.Err != nil {
		help = "Status unavailable: " + singleLine(m.data.Err.Error())
	}

	content := strings.Join([]string{
		pad(heading, width),
		pad(summary, width),
		"",
		pad(strings.Join(tabs, " "), width),
		m.panelsView(),
		pad(footer, width),
		pad(muted.Render(help), width),
	}, "\n")
	view := tea.NewView(lipgloss.NewStyle().Padding(1, 1, 0, 1).Render(content))
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

// CleanText removes terminal controls while preserving newlines and tabs.
func CleanText(s string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsControl(r) && r != '\n' && r != '\t' {
			return -1
		}

		return r
	}, s)
}

func singleLine(s string) string { return strings.Join(strings.Fields(CleanText(s)), " ") }

func shortPath(path string) string {
	home, _ := os.UserHomeDir()
	if path == home {
		return "~"
	}

	if strings.HasPrefix(path, home+"/") {
		path = "~" + strings.TrimPrefix(path, home)
	}

	return singleLine(path)
}
