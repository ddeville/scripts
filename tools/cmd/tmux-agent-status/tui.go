package main

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

type area string

const (
	agentsArea    area = "agents"
	worktreesArea area = "worktrees"
)

type areaState struct {
	list                   tui.List
	details                viewport.Model
	detailsFocus, expanded bool
}

func newAreaState() areaState {
	state := areaState{list: tui.NewList(), details: viewport.New()}
	state.details.KeyMap = viewport.KeyMap{Up: keys.up, Down: keys.down}
	state.details.MouseWheelEnabled = false

	return state
}

type (
	tuiOptions struct {
		client, pane, root, directory string
		area                          area
	}
	tickMsg struct{}
	openMsg struct {
		pane, session string
		err           error
	}
)

type model struct {
	ctx                     context.Context //nolint:containedctx // Bubble Tea callbacks share the lifetime of the program.
	area                    area
	agentView, worktreeView areaState
	width, height           int

	data                                            snapshot
	order                                           map[string]int
	selected, initialPane, originPane, originThread string
	filter                                          int
	activity                                        activity
	activityGeneration                              uint64
	activityCancel                                  context.CancelFunc

	trees                  []worktree.Info
	changes                map[string]string
	treeGeneration         uint64
	nextStatus             int
	sessionsReady, loading bool
	treeError              string
	root, source           string

	notice                    string
	busy                      bool
	targetPane, targetSession string
	create                    *createForm
	remove                    *removeForm
	planVersion               uint64
}

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

func tick() tea.Cmd { return tea.Tick(time.Second, func(time.Time) tea.Msg { return tickMsg{} }) }

func (m *model) Init() tea.Cmd { return tea.Batch(fetch(m.ctx), m.loadTreeStatus()) }

func (m *model) activeView() *areaState {
	if m.area == worktreesArea {
		return &m.worktreeView
	}

	return &m.agentView
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

func (m *model) filtered(filter int) []agent {
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

const (
	filterAll = iota
	filterAttention
	filterWorking
	filterUnread
	filterIdle
)

var filters = []string{"All", "Needs you", "Working", "Unread", "Idle"}

func agentRow(a agent) tui.ListItem {
	style, label, _ := stateStyle(a.State)

	indicator := "●"
	if a.State == "idle" {
		indicator = "○"
	}

	title := a.Title
	if a.ParentID != nil {
		title = "↳ " + title
	}

	return tui.ListItem{ID: a.ID, Group: cmp.Or(tui.ShortPath(a.Cwd), "Unknown location"), Title: title, Subtitle: a.Preview, Status: label, Indicator: indicator, Style: style}
}

func (m *model) selectAgent(id string) tea.Cmd {
	if m.selected == id {
		return nil
	}

	m.selected, m.notice = id, ""
	m.agentView.details.GotoTop()
	m.activity = activity{ID: id}
	m.updateAgentDetails()

	return m.refreshActivity()
}

func (m *model) updateAgents() tea.Cmd {
	agents := m.filtered(m.filter)
	slices.SortStableFunc(agents, func(a, b agent) int { return cmp.Compare(a.Cwd, b.Cwd) })

	m.agentView.list.Items = make([]tui.ListItem, 0, len(agents))
	for _, a := range agents {
		m.agentView.list.Items = append(m.agentView.list.Items, agentRow(a))
	}

	selected := m.selected
	if m.initialPane != "" {
		for _, a := range agents {
			if slices.Contains(a.Panes, m.initialPane) {
				selected = a.ID
				break
			}
		}

		m.initialPane = ""
	}

	m.agentView.list.SelectID(selected)
	cmd := m.selectAgent(m.agentView.list.SelectedID())
	m.updateAgentDetails()

	return cmd
}

func (m *model) updatePanels() {
	for _, which := range []area{agentsArea, worktreesArea} {
		view := &m.agentView
		if which == worktreesArea {
			view = &m.worktreeView
		}

		left, right, rows := m.panelDimensions(which)
		view.list.SetSize(left-4, rows)

		width := left - 4
		if right > 0 {
			width = right - 4
		}

		view.details.SetWidth(max(1, width))
		view.details.SetHeight(rows)
	}

	m.updateAgentDetails()
	m.updateWorktreeDetails()

	if m.create != nil {
		m.create.setWidth(m.width)
		m.updateThreadChoices()
	}
}

func (m *model) updateAgentDetails() {
	m.agentView.details.SetContent(m.detailContent(m.agentView.details.Width()))
}

func (m *model) openAgent(id string) tea.Cmd {
	if id == "" || m.busy {
		return nil
	}

	m.busy = true
	data := m.data

	return func() tea.Msg {
		if data.Err != nil || time.Since(data.At) > 10*time.Second {
			return openMsg{err: errStaleStatus}
		}

		ctx, cancel := context.WithTimeout(m.ctx, time.Second)
		defer cancel()

		panes, err := paneMatches(ctx, data.IDs)
		if err != nil {
			return openMsg{err: err}
		}

		if len(panes[id]) != 1 {
			return openMsg{err: fmt.Errorf("%w, found %d", errPaneMatch, len(panes[id]))}
		}

		return openMsg{pane: panes[id][0]}
	}
}

func (m *model) openItem(id string) tea.Cmd {
	if m.area == agentsArea {
		return m.openAgent(id)
	}

	return m.openWorktree(id)
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // Signature required by tea.Model.
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.updatePanels()
	case snapshot:
		if msg.Err != nil {
			m.data.Err = msg.Err
			if m.create != nil {
				m.create.originPending = false
			}

			return m, tick()
		}

		for _, a := range msg.Agents {
			if _, ok := m.order[a.ID]; !ok {
				m.order[a.ID] = len(m.order)
			}

			if m.originThread == "" && slices.Contains(a.Panes, m.originPane) {
				m.originThread = a.ID
			}
		}

		slices.SortFunc(msg.Agents, func(a, b agent) int { return cmp.Compare(m.order[a.ID], m.order[b.ID]) })
		m.data = msg

		cmd := m.updateAgents()
		if cmd == nil && m.selected != "" && m.activityCancel == nil {
			cmd = m.refreshActivity()
		}

		m.updateThreadChoices()

		return m, tea.Batch(tick(), cmd)
	case tickMsg:
		return m, fetch(m.ctx)
	case activity:
		if msg.ID == m.selected && msg.generation == m.activityGeneration {
			m.activity = msg
			m.activityCancel = nil
			m.updateAgentDetails()
		}
	case openMsg:
		m.busy = false
		if msg.err != nil {
			m.notice = tui.SingleLine(msg.err.Error())
			return m, nil
		}

		m.targetPane, m.targetSession = msg.pane, msg.session

		return m, tea.Quit
	case treeLoadedMsg, treeStatusMsg, treeSessionsMsg:
		return m, m.updateWorktrees(msg)
	case createdMsg:
		return m, m.created(msg)
	case plannedMsg:
		if m.remove != nil && msg.version == m.planVersion {
			m.remove.plan, m.remove.err, m.remove.checking = msg.plan, msg.err, false
		}
	case removedMsg:
		return m, m.removed(msg)
	case tea.KeyPressMsg:
		return m, m.handleKey(msg)
	default:
		if m.create != nil && !m.create.picking {
			return m, m.create.updateInput(msg)
		}
	}

	return m, nil
}

func (m *model) handleKey(msg tea.KeyPressMsg) tea.Cmd {
	if m.busy {
		return nil
	}

	if msg.String() == "ctrl+c" {
		return tea.Quit
	}

	if m.create != nil {
		return m.createKey(msg)
	}

	if m.remove != nil {
		return m.removeKey(msg)
	}

	view := m.activeView()
	switch {
	case key.Matches(msg, keys.quit):
		return tea.Quit
	case key.Matches(msg, keys.agents):
		m.area = agentsArea
		m.notice = ""
	case key.Matches(msg, keys.worktrees):
		m.area = worktreesArea
		m.notice = ""
	case key.Matches(msg, keys.create):
		return m.beginCreate()
	case key.Matches(msg, keys.remove) && m.area == worktreesArea:
		return m.beginRemove()
	case key.Matches(msg, keys.refresh) && m.area == worktreesArea:
		return m.reloadWorktrees(m.worktreeView.list.SelectedID())
	case key.Matches(msg, keys.nextFilter, keys.previousFilter, keys.attention) && m.area == agentsArea:
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
		view.detailsFocus = false
		view.expanded = false
	case key.Matches(msg, keys.details):
		view.detailsFocus = true
	case key.Matches(msg, keys.expand):
		view.expanded = !view.expanded
		view.detailsFocus = view.expanded
	case key.Matches(msg, keys.open):
		return m.openItem(view.list.SelectedID())
	case key.Matches(msg, keys.jump):
		position := int(msg.String()[0] - '0')
		if position < len(view.list.Items) {
			return m.openItem(view.list.Items[position].ID)
		}
	default:
		if view.detailsFocus {
			var cmd tea.Cmd

			switch {
			case key.Matches(msg, keys.first):
				view.details.GotoTop()
			case key.Matches(msg, keys.last):
				view.details.GotoBottom()
			default:
				view.details, cmd = view.details.Update(msg)
			}

			return cmd
		}

		before := view.list.SelectedID()
		view.list.Move(msg)

		if m.area == agentsArea {
			return m.selectAgent(view.list.SelectedID())
		}

		if before != view.list.SelectedID() {
			view.details.GotoTop()
		}

		m.updateWorktreeDetails()
	}

	m.updatePanels()

	return nil
}

func runTUI(ctx context.Context, options tuiOptions) error {
	uiCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	source := options.directory
	if resolved, err := filepath.EvalSymlinks(source); err == nil {
		source = resolved
	}

	initial := &model{
		ctx: uiCtx, area: options.area, root: options.root, source: source,
		order: map[string]int{}, width: 100, height: 30, changes: map[string]string{},
		agentView: newAreaState(), worktreeView: newAreaState(), initialPane: options.pane, originPane: options.pane,
	}

	items, err := worktree.Discover(options.root)
	if err != nil {
		initial.treeError = err.Error()
	}

	initial.trees = items
	initial.updateTreeList("")

	for _, item := range items {
		if source == item.Path || strings.HasPrefix(source, item.Path+string(filepath.Separator)) {
			initial.worktreeView.list.SelectID(item.Path)
			break
		}
	}

	initial.updatePanels()
	result, err := tea.NewProgram(initial, tea.WithContext(uiCtx), tea.WithoutSignalHandler()).Run()

	cancel()

	if err != nil {
		return fmt.Errorf("run status TUI: %w", err)
	}

	if final, ok := result.(*model); ok {
		if final.targetPane != "" {
			if err := tmux.SwitchPane(ctx, final.targetPane, options.client); err != nil {
				return fmt.Errorf("open selected agent: %w", err)
			}
		}

		if final.targetSession != "" {
			if err := tmux.SwitchSession(ctx, final.targetSession, options.client); err != nil {
				return fmt.Errorf("open worktree session: %w", err)
			}
		}
	}

	return nil
}
