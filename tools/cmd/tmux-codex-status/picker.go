package main

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
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
	ctx           context.Context //nolint:containedctx // Bubble Tea callbacks have no context parameter.
	data          snapshot
	positions     map[string]int
	selected      string
	filter        int
	width, height int
	detailsFocus  bool
	expanded      bool
	scroll        int
	activity      activity
	notice        string
	opening       bool
	target        string
}

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

func fetchActivity(ctx context.Context, id string) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
		defer cancel()

		data, err := detail(ctx, id)

		return activity{ID: id, Entries: activityEntries(data), Err: err}
	}
}

func tick() tea.Cmd { return tea.Tick(2*time.Second, func(time.Time) tea.Msg { return tickMsg{} }) }

func (m model) Init() tea.Cmd { return fetch(m.ctx) }

func (m model) filtered(filter int) []agent {
	var result []agent

	for _, a := range m.data.Agents {
		match := false

		switch filter {
		case 0:
			match = true
		case 1:
			match = a.NeedsAttention
		case 2:
			match = a.State == "working"
		case 3:
			match = a.State == "ready"
		case 4:
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

	m.selected, m.scroll, m.notice = id, 0, ""

	m.activity = activity{ID: id}
	if id == "" {
		return nil
	}

	return fetchActivity(m.ctx, id)
}

func (m *model) keepSelection() tea.Cmd {
	agents := m.filtered(m.filter)
	for _, a := range agents {
		if a.ID == m.selected {
			return nil
		}
	}

	if len(agents) == 0 {
		return m.selectAgent("")
	}

	return m.selectAgent(agents[0].ID)
}

func (m model) open(id string) tea.Cmd {
	if id == "" || m.opening {
		return nil
	}

	return func() tea.Msg {
		if m.data.Err != nil || time.Since(m.data.At) > 10*time.Second {
			return openMsg{err: errStaleStatus}
		}

		ctx, cancel := context.WithTimeout(m.ctx, time.Second)
		defer cancel()

		panes, err := paneMatches(ctx, m.data.IDs)
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
	case snapshot:
		if msg.Err != nil {
			m.data.Err = msg.Err
			return m, tick()
		}

		for _, a := range msg.Agents {
			if _, ok := m.positions[a.ID]; !ok {
				m.positions[a.ID] = len(m.positions)
			}
		}

		sort.Slice(msg.Agents, func(i, j int) bool { return m.positions[msg.Agents[i].ID] < m.positions[msg.Agents[j].ID] })
		m.data = msg

		detailCmd := m.keepSelection()
		if detailCmd == nil && m.selected != "" {
			detailCmd = fetchActivity(m.ctx, m.selected)
		}

		return m, tea.Batch(tick(), detailCmd)
	case tickMsg:
		return m, fetch(m.ctx)
	case activity:
		if msg.ID == m.selected {
			m.activity = msg
		}
	case openMsg:
		m.opening = false
		if msg.err != nil {
			m.notice = clean(msg.err.Error())
			return m, nil
		}

		m.target = msg.pane

		return m, tea.Quit
	case tea.KeyPressMsg:
		key := msg.String()
		switch key {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit
		case "tab", "shift+tab", "ctrl+f":
			switch key {
			case "ctrl+f":
				if m.filter == 1 {
					m.filter = 0
				} else {
					m.filter = 1
				}
			case "shift+tab":
				m.filter = (m.filter + len(filters) - 1) % len(filters)
			default:
				m.filter = (m.filter + 1) % len(filters)
			}

			cmd := m.keepSelection()

			return m, cmd
		case "h", "left":
			m.detailsFocus = false
			m.expanded = false
		case "l", "right":
			m.detailsFocus = true
		case "e":
			m.expanded = !m.expanded
			m.detailsFocus = m.expanded
		case "j", "down", "k", "up", "ctrl+d", "ctrl+u", "g", "G":
			delta := 1
			if key == "k" || key == "up" || key == "ctrl+u" {
				delta = -1
			}

			if key == "ctrl+d" || key == "ctrl+u" {
				delta *= max(1, (m.height-10)/4)
			}

			if m.detailsFocus {
				left, right, rows := m.panelDimensions()

				width := left - 4
				if right > 0 {
					width = right - 4
				}

				limit := max(0, len(m.detailLines(width))-rows)

				m.scroll = max(0, min(limit, min(m.scroll, limit)+delta))
				if key == "g" {
					m.scroll = 0
				}

				if key == "G" {
					m.scroll = limit
				}
			} else {
				agents := m.filtered(m.filter)
				if len(agents) == 0 {
					break
				}

				index := 0

				for i, a := range agents {
					if a.ID == m.selected {
						index = i
					}
				}

				index = ((index+delta)%len(agents) + len(agents)) % len(agents)
				if key == "g" {
					index = 0
				}

				if key == "G" {
					index = len(agents) - 1
				}

				cmd := m.selectAgent(agents[index].ID)

				return m, cmd
			}
		case "enter":
			cmd := m.open(m.selected)
			m.opening = cmd != nil

			return m, cmd
		default:
			if position := strings.Index("0123456789", key); len(key) == 1 && position >= 0 {
				for _, a := range m.filtered(m.filter) {
					if m.positions[a.ID] == position {
						cmd := m.open(a.ID)
						m.opening = cmd != nil

						return m, cmd
					}
				}
			}
		}
	}

	return m, nil
}

func runPicker(ctx context.Context, client string) error {
	uiCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	initial := model{ctx: uiCtx, positions: map[string]int{}, width: 100, height: 30}
	result, err := tea.NewProgram(initial, tea.WithContext(uiCtx), tea.WithoutSignalHandler()).Run()

	cancel()

	if err != nil {
		return fmt.Errorf("run picker: %w", err)
	}

	if final, ok := result.(model); ok && final.target != "" {
		return switchPane(ctx, final.target, client)
	}

	return nil
}
