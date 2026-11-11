package ui

import (
	"encoding/json"
	"fmt"
	"slices"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
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

func (m *model) summary() string {
	if m.data.Err != nil {
		if m.data.At.IsZero() {
			return tui.Red.Render("Agent status unavailable")
		}

		return tui.Red.Render("Status unavailable · showing last known data")
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

func (m *model) detailContent(width int) string {
	index := slices.IndexFunc(m.data.Agents, func(a agents.Agent) bool { return a.ID == m.selected })
	if index < 0 {
		return tui.Muted.Render("No conversation selected")
	}

	a := m.data.Agents[index]
	style, _, hint := stateStyle(a.State)

	lines := detailHeader(a.Title, a.Cwd, style.Render(hint), "to open")

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

func activityEntries(data agents.Details) []entry {
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
