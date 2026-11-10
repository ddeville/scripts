package agentstatus

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

type (
	tickMsg struct{}
	openMsg struct {
		pane string
		err  error
	}
)

//nolint:recvcheck // Bubble Tea uses value updates; pointer helpers mutate the current update's copy.
type model struct {
	ctx                context.Context //nolint:containedctx // Bubble Tea callbacks have no context parameter.
	data               snapshot
	order              map[string]int
	selected           string
	initialPane        string
	filter             int
	width, height      int
	detailsFocus       bool
	expanded           bool
	agents             agentList
	details            viewport.Model
	activity           activity
	activityGeneration uint64
	activityCancel     context.CancelFunc
	notice             string
	opening            bool
	target             string
}

const (
	filterAll = iota
	filterAttention
	filterWorking
	filterUnread
	filterIdle
)

var filters = []string{"All", "Needs you", "Working", "Unread", "Idle"}

var (
	errStaleStatus = errors.New("status is stale; wait for a fresh update")
	errPaneMatch   = errors.New("expected one live pane")
)

func fetch(ctx context.Context) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
		defer cancel()

		return collect(ctx)
	}
}

func (m *model) refreshActivity() tea.Cmd {
	if m.activityCancel != nil {
		m.activityCancel()
		m.activityCancel = nil
	}

	m.activityGeneration++
	if m.selected == "" {
		return nil
	}

	ctx, cancel := context.WithTimeout(m.ctx, 3*time.Second)
	m.activityCancel = cancel
	id, generation := m.selected, m.activityGeneration

	return func() tea.Msg {
		defer cancel()

		data, err := detail(ctx, id)

		return activity{ID: id, generation: generation, Entries: activityEntries(data), Err: err}
	}
}

func tick() tea.Cmd { return tea.Tick(time.Second, func(time.Time) tea.Msg { return tickMsg{} }) }

func (m model) Init() tea.Cmd { return fetch(m.ctx) }

func (m model) filtered(filter int) []agent {
	var result []agent

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

func (m *model) selectAgent(id string) tea.Cmd {
	if m.selected == id {
		return nil
	}

	m.selected, m.notice = id, ""
	m.details.GotoTop()

	m.activity = activity{ID: id}
	m.updateDetails()

	return m.refreshActivity()
}

func (m *model) updateAgents() tea.Cmd {
	agents := m.filtered(m.filter)
	slices.SortStableFunc(agents, func(a, b agent) int { return cmp.Compare(a.Cwd, b.Cwd) })

	m.agents.items = make([]agentItem, 0, len(agents))
	for i, a := range agents {
		m.agents.items = append(m.agents.items, agentItem{agent: a, position: i})
	}

	index := slices.IndexFunc(agents, func(a agent) bool { return a.ID == m.selected })
	if m.initialPane != "" && !m.data.At.IsZero() {
		index = slices.IndexFunc(agents, func(a agent) bool {
			return slices.Contains(a.Panes, m.initialPane)
		})
		m.initialPane = ""
	}

	m.agents.selectIndex(max(0, index))
	cmd := m.selectAgent(m.selectedAgentID())
	m.updateDetails()

	return cmd
}

func (m model) selectedAgentID() string {
	if len(m.agents.items) > 0 {
		return m.agents.items[m.agents.index].ID
	}

	return ""
}

func (m *model) updatePanels() {
	left, right, rows := m.panelDimensions()
	m.agents.setSize(left-4, rows)

	width := left - 4
	if right > 0 {
		width = right - 4
	}

	m.details.SetWidth(width)
	m.details.SetHeight(rows)
	m.updateDetails()
}

func (m *model) updateDetails() {
	m.details.SetContent(m.detailContent(m.details.Width()))
}

func (m *model) open(id string) tea.Cmd {
	if id == "" || m.opening {
		return nil
	}

	m.opening = true

	return func() tea.Msg {
		if m.data.Err != nil || time.Since(m.data.At) > 10*time.Second {
			return openMsg{err: errStaleStatus}
		}

		ctx, cancel := context.WithTimeout(m.ctx, time.Second)
		defer cancel()

		panes, err := tmux.PaneMatches(ctx, m.data.IDs)
		if err != nil {
			return openMsg{err: err}
		}

		if len(panes[id]) != 1 {
			return openMsg{err: fmt.Errorf("%w, found %d", errPaneMatch, len(panes[id]))}
		}

		return openMsg{pane: panes[id][0]}
	}
}

func (m model) Update(message tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // Signature required by tea.Model.
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.updatePanels()
	case snapshot:
		if msg.Err != nil {
			m.data.Err = msg.Err
			return m, tick()
		}

		for _, a := range msg.Agents {
			if _, ok := m.order[a.ID]; !ok {
				m.order[a.ID] = len(m.order)
			}
		}

		slices.SortFunc(msg.Agents, func(a, b agent) int {
			return cmp.Compare(m.order[a.ID], m.order[b.ID])
		})
		m.data = msg

		detailCmd := m.updateAgents()
		if detailCmd == nil && m.selected != "" && m.activityCancel == nil {
			detailCmd = m.refreshActivity()
		}

		return m, tea.Batch(tick(), detailCmd)
	case tickMsg:
		return m, fetch(m.ctx)
	case activity:
		if msg.ID == m.selected && msg.generation == m.activityGeneration {
			m.activity = msg
			m.activityCancel = nil
			m.updateDetails()
		}
	case openMsg:
		m.opening = false
		if msg.err != nil {
			m.notice = singleLine(msg.err.Error())
			return m, nil
		}

		m.target = msg.pane

		return m, tea.Quit
	case tea.KeyPressMsg:
		cmd := m.handleKey(msg)

		return m, cmd
	}

	return m, nil
}

func (m *model) handleKey(msg tea.KeyPressMsg) tea.Cmd {
	switch {
	case key.Matches(msg, keys.quit):
		return tea.Quit
	case key.Matches(msg, keys.nextFilter, keys.previousFilter, keys.attention):
		switch {
		case key.Matches(msg, keys.attention):
			if m.filter == filterAttention {
				m.filter = filterAll
			} else {
				m.filter = filterAttention
			}
		case key.Matches(msg, keys.previousFilter):
			m.filter = (m.filter + len(filters) - 1) % len(filters)
		default:
			m.filter = (m.filter + 1) % len(filters)
		}

		return m.updateAgents()
	case key.Matches(msg, keys.list):
		m.detailsFocus = false
		m.expanded = false
	case key.Matches(msg, keys.details):
		m.detailsFocus = true
	case key.Matches(msg, keys.expand):
		m.expanded = !m.expanded
		m.detailsFocus = m.expanded
	case key.Matches(msg, keys.open):
		return m.open(m.selected)
	case key.Matches(msg, keys.jump):
		position := int(msg.String()[0] - '0')
		if position < len(m.agents.items) {
			return m.open(m.agents.items[position].ID)
		}

		return nil
	default:
		var cmd tea.Cmd

		if m.detailsFocus {
			switch {
			case key.Matches(msg, keys.first):
				m.details.GotoTop()
			case key.Matches(msg, keys.last):
				m.details.GotoBottom()
			default:
				m.details, cmd = m.details.Update(msg)
			}
		} else {
			m.agents.move(msg)
			cmd = m.selectAgent(m.selectedAgentID())
		}

		return cmd
	}

	m.updatePanels()

	return nil
}

// RunPicker opens the agent picker and switches to the selected pane.
func RunPicker(ctx context.Context, client, pane string) error {
	uiCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	initial := model{
		ctx: uiCtx, order: map[string]int{}, width: 100, height: 30,
		agents: newAgentList(), details: viewport.New(), initialPane: pane,
	}
	initial.details.KeyMap = viewport.KeyMap{Up: keys.up, Down: keys.down}
	initial.details.MouseWheelEnabled = false
	initial.updatePanels()
	result, err := tea.NewProgram(initial, tea.WithContext(uiCtx), tea.WithoutSignalHandler()).Run()

	cancel()

	if err != nil {
		return fmt.Errorf("run picker: %w", err)
	}

	if final, ok := result.(model); ok && final.target != "" {
		if err := tmux.SwitchPane(ctx, final.target, client); err != nil {
			return fmt.Errorf("open selected agent: %w", err)
		}
	}

	return nil
}
