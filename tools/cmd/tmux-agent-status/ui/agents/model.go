// Package agents manages the Agents section and its conversation previews.
package agents

import (
	"cmp"
	"context"
	"fmt"
	"slices"
	"time"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"

	agentdata "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/internal/tui"
)

// Model owns agent snapshots, filtering, selection, and activity requests.
type Model struct {
	Panel                                           panel.Model
	hosts                                           map[string]*destination
	choices                                         map[string]Choice
	initialHost                                     string
	scanErr                                         error
	selected, initialPane, originPane, originThread string
	filter                                          int
	activity                                        activity
	activityGeneration                              uint64
	activityCancel                                  context.CancelFunc
}

type tickMsg struct{}

// New starts the section with the originating pane as its initial selection.
func New(pane string) Model {
	return Model{Panel: panel.New(), initialPane: pane, originPane: pane, hosts: map[string]*destination{"": {}}}
}

// OriginID returns the conversation found in the originating tmux pane.
func (m *Model) OriginID() string { return m.originThread }

// Init begins polling agent status.
func (m *Model) Init(ctx context.Context) tea.Cmd { return scan(ctx) }

// Update handles section input and applies status and activity results.
func (m *Model) Update(ctx context.Context, message tea.Msg) tea.Cmd {
	switch msg := message.(type) {
	case panesMsg:
		return m.fetch(ctx, msg)
	case StatusMsg:
		dest := m.hosts[msg.Host]
		dest.busy = false

		dest.data = msg.data
		if msg.Host == "" && m.originThread == "" {
			for _, a := range msg.data.Agents {
				if slices.Contains(a.Panes, m.originPane) {
					m.originThread = a.ID
				}
			}
		}

		cmd := m.updateAgents(ctx)
		if msg.Host == m.initialHost {
			m.initialPane = ""
		}

		if choice, ok := m.Find(m.selected); ok && choice.Pane.Host == msg.Host && cmd == nil && m.activityCancel == nil {
			return m.refreshActivity(ctx)
		}

		return cmd
	case tickMsg:
		return scan(ctx)
	case activity:
		if msg.ID == m.selected && msg.generation == m.activityGeneration {
			m.activity = msg
			m.activityCancel = nil
			m.updateAgentDetails()
		}
	case tea.KeyPressMsg:
		m.initialPane = ""
		if key.Matches(msg, Keys.NextFilter, Keys.PreviousFilter, Keys.Attention) {
			return m.changeFilter(ctx, msg)
		}

		cmd := m.Panel.Update(msg)
		selected := m.selectAgent(ctx, m.Panel.List.SelectedID())
		m.updateAgentDetails()

		return tea.Batch(cmd, selected)
	}

	return nil
}

// SetSize updates the shared panels and rewraps the selected conversation.
func (m *Model) SetSize(width, rows int) {
	m.Panel.SetSize(width, rows)
	m.updateAgentDetails()
}

func (m *Model) changeFilter(ctx context.Context, msg tea.KeyPressMsg) tea.Cmd {
	switch {
	case key.Matches(msg, Keys.Attention):
		if m.filter == filterAttention {
			m.filter = filterAll
		} else {
			m.filter = filterAttention
		}
	case key.Matches(msg, Keys.PreviousFilter):
		m.filter = (m.filter + len(filters) - 1) % len(filters)
	default:
		m.filter = (m.filter + 1) % len(filters)
	}

	return m.updateAgents(ctx)
}

const (
	filterAll = iota
	filterAttention
	filterWorking
	filterUnread
	filterIdle
)

var filters = []string{"All", "Needs you", "Working", "Unread", "Idle"}

func (m *Model) refreshActivity(ctx context.Context) tea.Cmd {
	if m.activityCancel != nil {
		m.activityCancel()
		m.activityCancel = nil
	}

	m.activityGeneration++

	choice, ok := m.Find(m.selected)
	if !ok {
		return nil
	}

	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	m.activityCancel = cancel
	id, generation := m.selected, m.activityGeneration

	return func() tea.Msg {
		defer cancel()

		data, err := choice.Source.ReadDetails(ctx, choice.Agent.ID)

		return activity{ID: id, generation: generation, Entries: activityEntries(data), Err: err}
	}
}

func (m *Model) filtered(filter int) []Choice {
	var result []Choice

	for _, c := range m.choices {
		a := c.Agent
		match := false

		switch filter {
		case filterAll:
			match = true
		case filterAttention:
			match = a.NeedsAttention
		case filterWorking:
			match = a.State == "working"
		case filterUnread:
			match = a.State == "ready"
		case filterIdle:
			match = a.State == "idle"
		}

		if match {
			result = append(result, c)
		}
	}

	return result
}

func (m *Model) selectAgent(ctx context.Context, id string) tea.Cmd {
	if m.selected == id {
		return nil
	}

	m.selected = id
	m.Panel.Details.GotoTop()
	m.activity = activity{ID: id}
	m.updateAgentDetails()

	return m.refreshActivity(ctx)
}

func (m *Model) updateAgents(ctx context.Context) tea.Cmd {
	m.choices = make(map[string]Choice)
	for _, dest := range m.hosts {
		for _, a := range dest.data.Agents {
			for _, pane := range a.Targets {
				c := Choice{Agent: a, Pane: pane, Source: &dest.source}
				m.choices[c.key()] = c
			}
		}
	}

	filtered := m.filtered(m.filter)
	slices.SortFunc(filtered, func(a, b Choice) int {
		return cmp.Or(cmp.Compare(a.Pane.SessionNumber, b.Pane.SessionNumber),
			cmp.Compare(a.Pane.Host, b.Pane.Host), cmp.Compare(a.Agent.Cwd, b.Agent.Cwd),
			cmp.Compare(len(a.Pane.ID), len(b.Pane.ID)), cmp.Compare(a.Pane.ID, b.Pane.ID))
	})

	selected := m.selected

	items := make([]tui.ListItem, 0, len(filtered))
	for _, c := range filtered {
		row := Row(c.Agent)

		row.ID, row.Group = c.key(), c.location()
		if len(c.Agent.Panes) > 1 {
			row.Title = c.Pane.ID + " · " + row.Title
		}

		items = append(items, row)
		if c.Pane.ID == m.initialPane {
			selected = row.ID
		}
	}

	m.Panel.List.SetItems(items, selected)
	cmd := m.selectAgent(ctx, m.Panel.List.SelectedID())
	m.updateAgentDetails()

	return cmd
}

func (m *Model) updateAgentDetails() {
	m.Panel.Details.SetContent(m.detailContent(m.Panel.Details.Width()))
}

// Row renders a conversation consistently in the list and fork chooser.
func Row(a agentdata.Agent) tui.ListItem {
	style, label, _ := stateStyle(a.State)
	if len(a.Panes) > 1 {
		label += fmt.Sprintf(" · %d panes", len(a.Panes))
	}

	indicator := "●"
	if a.State == "idle" {
		indicator = "○"
	}

	title := a.Title
	if a.ParentID != nil {
		title = "↳ " + title
	}

	return tui.ListItem{ID: a.ID, Group: cmp.Or(tui.ShortPath(a.Cwd), "Unknown location"), Title: title, Subtitle: a.Preview, Status: label, Indicator: indicator, StatusStyle: style}
}
