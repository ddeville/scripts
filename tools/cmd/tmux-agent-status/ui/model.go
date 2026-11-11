// Package ui presents the unified Agents and Worktrees terminal interface.
package ui

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

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

// Area identifies the section shown when the interface opens.
type Area string

const (
	// AgentsArea shows running conversations.
	AgentsArea Area = "agents"
	// WorktreesArea shows managed worktrees.
	WorktreesArea Area = "worktrees"
)

// Options supplies the initial area, source directory, and originating tmux client.
type Options struct {
	Client, Pane, Root, Directory string
	Area                          Area
}

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
	tickMsg struct{}
	openMsg struct {
		pane, session string
		err           error
	}
)

type model struct {
	ctx                     context.Context //nolint:containedctx // Bubble Tea callbacks share the lifetime of the program.
	area                    Area
	agentView, worktreeView areaState
	width, height           int

	data                                            agents.Snapshot
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
	busy, quitting            bool
	operationCancel           context.CancelFunc
	targetPane, targetSession string
	create                    *createForm
	remove                    *removeForm
	planVersion               uint64
}

var errStaleStatus = errors.New("status is stale; wait for a fresh update")

func fetch(ctx context.Context) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
		defer cancel()

		return agents.Collect(ctx)
	}
}

func tick() tea.Cmd { return tea.Tick(time.Second, func(time.Time) tea.Msg { return tickMsg{} }) }

func (m *model) Init() tea.Cmd { return tea.Batch(fetch(m.ctx), m.loadTreeStatus()) }

func (m *model) activeView() *areaState {
	if m.area == WorktreesArea {
		return &m.worktreeView
	}

	return &m.agentView
}

func (m *model) beginOperation() context.Context {
	ctx, cancel := context.WithCancel(m.ctx)
	m.busy, m.operationCancel = true, cancel

	return ctx
}

func (m *model) finishOperation() bool {
	m.operationCancel()
	m.operationCancel = nil
	m.busy = false

	return m.quitting
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

		data, err := agents.ReadDetails(ctx, id)

		return activity{ID: id, generation: generation, Entries: activityEntries(data), Err: err}
	}
}

func (m *model) filtered(filter int) []agents.Agent {
	var result []agents.Agent

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

func agentRow(a agents.Agent) tui.ListItem {
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
	filtered := m.filtered(m.filter)

	items := make([]tui.ListItem, 0, len(filtered))
	for _, a := range filtered {
		items = append(items, agentRow(a))
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

	m.agentView.list.SetItems(items, selected)
	cmd := m.selectAgent(m.agentView.list.SelectedID())
	m.updateAgentDetails()

	return cmd
}

func (m *model) updatePanels() {
	for _, which := range []Area{AgentsArea, WorktreesArea} {
		view := &m.agentView
		if which == WorktreesArea {
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
	m.updateRemovalDetails()

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

	operationCtx := m.beginOperation()
	data := m.data

	return func() tea.Msg {
		if data.Err != nil || time.Since(data.At) > 10*time.Second {
			return openMsg{err: errStaleStatus}
		}

		ctx, cancel := context.WithTimeout(operationCtx, time.Second)
		defer cancel()

		panes, err := agents.MatchPanes(ctx, data.IDs)
		if err != nil {
			return openMsg{err: err}
		}

		if len(panes[id]) != 1 {
			return openMsg{err: fmt.Errorf("%w, found %d", agents.ErrPaneMatch, len(panes[id]))}
		}

		return openMsg{pane: panes[id][0]}
	}
}

func (m *model) openItem(id string) tea.Cmd {
	if m.area == AgentsArea {
		return m.openAgent(id)
	}

	return m.openWorktree(id)
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // Signature required by tea.Model.
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.updatePanels()
	case agents.Snapshot:
		if msg.Err != nil {
			m.data.Err = msg.Err
			if m.create != nil {
				m.create.originPending = false
			}

			return m, tick()
		}

		for _, a := range msg.Agents {
			if m.originThread == "" && slices.Contains(a.Panes, m.originPane) {
				m.originThread = a.ID
			}
		}

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
		if m.finishOperation() {
			return m, tea.Quit
		}

		if msg.err != nil {
			m.notice = tui.SingleLine(msg.err.Error())
			return m, nil
		}

		m.targetPane, m.targetSession = msg.pane, msg.session

		return m, tea.Quit
	case treeLoadedMsg, treeStatusMsg, treeSessionsMsg:
		return m, m.updateWorktrees(msg)
	case createdMsg:
		if m.finishOperation() {
			return m, tea.Quit
		}

		return m, m.created(msg)
	case plannedMsg:
		if m.remove != nil && msg.version == m.planVersion {
			m.remove.plan, m.remove.err, m.remove.checking = msg.plan, msg.err, false
			m.updateRemovalDetails()
		}
	case removedMsg:
		if m.finishOperation() {
			return m, tea.Quit
		}

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
	if msg.String() == "ctrl+c" {
		if m.busy {
			m.quitting = true
			m.operationCancel()

			return nil
		}

		return tea.Quit
	}

	if m.busy {
		return nil
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
		m.area = AgentsArea
		m.notice = ""
	case key.Matches(msg, keys.worktrees):
		m.area = WorktreesArea
		m.notice = ""
	case key.Matches(msg, keys.create):
		return m.beginCreate()
	case key.Matches(msg, keys.remove) && m.area == WorktreesArea:
		return m.beginRemove()
	case key.Matches(msg, keys.refresh) && m.area == WorktreesArea:
		return m.reloadWorktrees(m.worktreeView.list.SelectedID())
	case key.Matches(msg, keys.nextFilter, keys.previousFilter, keys.attention) && m.area == AgentsArea:
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
		if item, ok := view.list.Item(position); ok {
			return m.openItem(item.ID)
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

		if m.area == AgentsArea {
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

// Run opens the interface and switches to the selected tmux pane or session on exit.
func Run(ctx context.Context, options Options) error {
	uiCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	source := options.Directory
	if resolved, err := filepath.EvalSymlinks(source); err == nil {
		source = resolved
	}

	initial := &model{
		ctx: uiCtx, area: options.Area, root: options.Root, source: source,
		width: 100, height: 30, changes: map[string]string{},
		agentView: newAreaState(), worktreeView: newAreaState(), initialPane: options.Pane, originPane: options.Pane,
	}

	items, err := worktree.Discover(options.Root)
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
			if err := tmux.SwitchPane(ctx, final.targetPane, options.Client); err != nil {
				return fmt.Errorf("open selected agent: %w", err)
			}
		}

		if final.targetSession != "" {
			if err := tmux.SwitchSession(ctx, final.targetSession, options.Client); err != nil {
				return fmt.Errorf("open worktree session: %w", err)
			}
		}
	}

	return nil
}
