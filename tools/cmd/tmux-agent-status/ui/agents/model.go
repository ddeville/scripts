// Package agents manages the Agents section and its conversation previews.
package agents

import (
	"cmp"
	"context"
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
	data                                            agentdata.Snapshot
	selected, initialPane, originPane, originThread string
	filter                                          int
	activity                                        activity
	activityGeneration                              uint64
	activityCancel                                  context.CancelFunc
}

type tickMsg struct{}

// New starts the section with the originating pane as its initial selection.
func New(pane string) Model {
	return Model{Panel: panel.New(), initialPane: pane, originPane: pane}
}

// Snapshot returns the last known agent data and connection state.
func (m *Model) Snapshot() agentdata.Snapshot { return m.data }

// OriginID returns the conversation found in the originating tmux pane.
func (m *Model) OriginID() string { return m.originThread }

// Init begins polling agent status.
func (m *Model) Init(ctx context.Context) tea.Cmd { return fetch(ctx) }

func fetch(ctx context.Context) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
		defer cancel()

		return agentdata.Collect(ctx)
	}
}

func tick() tea.Cmd { return tea.Tick(time.Second, func(time.Time) tea.Msg { return tickMsg{} }) }

// Update applies status and activity results, including stale-result checks.
func (m *Model) Update(ctx context.Context, message tea.Msg) tea.Cmd {
	switch msg := message.(type) {
	case agentdata.Snapshot:
		if msg.Err != nil {
			m.data.Err = msg.Err
			return tick()
		}

		for _, a := range msg.Agents {
			if m.originThread == "" && slices.Contains(a.Panes, m.originPane) {
				m.originThread = a.ID
			}
		}

		m.data = msg

		cmd := m.updateAgents(ctx)
		if cmd == nil && m.selected != "" && m.activityCancel == nil {
			cmd = m.refreshActivity(ctx)
		}

		return tea.Batch(tick(), cmd)
	case tickMsg:
		return fetch(ctx)
	case activity:
		if msg.ID == m.selected && msg.generation == m.activityGeneration {
			m.activity = msg
			m.activityCancel = nil
			m.updateAgentDetails()
		}
	}

	return nil
}

// SetSize updates the shared panels and rewraps the selected conversation.
func (m *Model) SetSize(width, rows int) {
	m.Panel.SetSize(width, rows)
	m.updateAgentDetails()
}

// Navigate updates panel focus or selection and loads newly selected activity.
func (m *Model) Navigate(ctx context.Context, msg tea.KeyPressMsg) tea.Cmd {
	cmd := m.Panel.Update(msg)
	selected := m.selectAgent(ctx, m.Panel.List.SelectedID())
	m.updateAgentDetails()

	return tea.Batch(cmd, selected)
}

// Filter changes the active status filter using its keyboard binding.
func (m *Model) Filter(ctx context.Context, msg tea.KeyPressMsg) tea.Cmd {
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
	if m.selected == "" {
		return nil
	}

	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	m.activityCancel = cancel
	id, generation := m.selected, m.activityGeneration

	return func() tea.Msg {
		defer cancel()

		data, err := agentdata.ReadDetails(ctx, id)

		return activity{ID: id, generation: generation, Entries: activityEntries(data), Err: err}
	}
}

func (m *Model) filtered(filter int) []agentdata.Agent {
	var result []agentdata.Agent

	for _, a := range m.data.Agents {
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
			result = append(result, a)
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
	filtered := m.filtered(m.filter)

	items := make([]tui.ListItem, 0, len(filtered))
	for _, a := range filtered {
		items = append(items, Row(a))
	}

	selected := m.selected
	if m.initialPane != "" {
		for _, a := range filtered {
			if slices.Contains(a.Panes, m.initialPane) {
				selected = a.ID
				break
			}
		}

		m.initialPane = ""
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
