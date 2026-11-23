package agents

import (
	"cmp"
	"encoding/json"
	"fmt"
	"slices"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	agentdata "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/internal/tui"
)

func stateStyle(state string) (lipgloss.Style, string, string) {
	switch state {
	case "approval":
		return tui.Yellow, "Approve", "Waiting for approval. Open the agent to approve or reject."
	case "input":
		return tui.Yellow, "Reply", "Waiting for your answer. Open the agent to reply."
	case "error":
		return tui.Red, "Check error", "The agent reported an error. Open it to investigate."
	case "ready":
		return tui.Green, "Read result", "A completed result is waiting to be read."
	case "working":
		return tui.Cyan, "Working", "Working. Open the agent to follow progress or steer it."
	case "idle":
		return tui.Muted, "Idle", "Idle. Open the agent to continue the conversation."
	default:
		return tui.Muted, "Check status", "Status is unknown. Open the agent to check."
	}
}

// Summary describes agents that need attention.
func (m *Model) Summary() string {
	if m.loading() {
		return tui.Muted.Render("Loading agents…")
	}

	counts := map[string]int{}

	for _, dest := range m.hosts {
		for state, count := range dest.data.Counts {
			counts[state] += count
		}
	}

	var parts []string

	for _, state := range []string{"approval", "input", "error", "ready"} {
		if count := counts[state]; count > 0 {
			style, label, _ := stateStyle(state)
			parts = append(parts, style.Render(fmt.Sprintf("%s %d", label, count)))
		}
	}

	if len(parts) == 0 {
		if m.issue() != "" {
			return tui.Yellow.Render("Some agent status is unavailable")
		}

		return tui.Muted.Render("Nothing needs your attention")
	}

	return "Needs you:  " + strings.Join(parts, tui.Muted.Render("  ·  "))
}

func (c Choice) location() string {
	if c.Pane.Host != "" {
		return tui.CleanLine(c.Pane.Host + " · " + cmp.Or(c.Agent.Cwd, "Unknown location"))
	}

	return cmp.Or(tui.ShortPath(c.Agent.Cwd), "Unknown location")
}

func (m *Model) detailContent(width int) string {
	c, ok := m.Find(m.selected)
	if !ok {
		return tui.Muted.Render("No conversation selected")
	}

	a := c.Agent
	style, _, hint := stateStyle(a.State)
	lines := panel.DetailHeader(a.Title, c.location(), style.Render(hint), "to open pane "+c.Pane.ID)

	if a.Error != nil {
		lines = append(lines, "", tui.Red.Render(tui.CleanText(*a.Error)))
	}

	entries := m.activity.Entries
	if len(entries) == 0 {
		entries = []entry{{"Prompt", a.Preview}}
	}

	if m.activity.Err != nil {
		lines = append(lines, "", tui.Red.Render(tui.CleanText(m.activity.Err.Error())))
	}

	for _, e := range entries {
		text := []rune(e.Text)
		if len(text) > 6000 {
			text = text[:6000]
		}

		body := strings.ReplaceAll(tui.CleanText(string(text)), "\t", "    ")
		if e.Label == "Error" {
			body = tui.Red.Render(body)
		}

		lines = append(lines, "", tui.Heading.Render(e.Label), body)
	}

	return ansi.Wrap(strings.Join(lines, "\n"), width, "")
}

type activity struct {
	ID         string
	generation uint64
	Entries    []entry
	Err        error
}

type entry struct{ Label, Text string }

func activityEntries(data agentdata.Details) []entry {
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

// View renders the agent list and selected conversation.
func (m *Model) View() string {
	empty := "No conversations match this status"
	if m.loading() {
		empty = "Loading agents…"
	}

	if m.issue() != "" && len(m.choices) == 0 {
		empty = "Could not read agent status"
	}

	return m.Panel.View(fmt.Sprintf("Agents · %d", m.Panel.List.Len()), "Selected agent", empty)
}

// Message provides connection errors or the current app notice for the footer.
func (m *Model) Message(notice string) string {
	if notice != "" {
		return tui.Muted.Render(tui.CleanLine(notice))
	}

	if issue := m.issue(); issue != "" {
		return tui.Red.Render(tui.SingleLine(issue))
	}

	return ""
}

func (m *Model) loading() bool {
	if m.scanErr != nil || len(m.choices) != 0 {
		return false
	}

	for _, dest := range m.hosts {
		if dest.data.At.IsZero() {
			return true
		}
	}

	return false
}

func (m *Model) issue() string {
	if m.scanErr != nil {
		return m.scanErr.Error()
	}

	var issues []string

	for host, dest := range m.hosts {
		if err := dest.data.Err; err != nil {
			issues = append(issues, cmp.Or(host, "local")+" · "+err.Error())
		}
	}

	slices.Sort(issues)

	return strings.Join(issues, "  ·  ")
}

// Toolbar renders status filters and their counts.
func (m *Model) Toolbar() string {
	tabs := make([]string, 0, len(filters))
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
