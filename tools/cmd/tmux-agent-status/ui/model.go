// Package ui presents the unified Agents and Worktrees terminal interface.
package ui

import (
	"context"
	"fmt"
	"path/filepath"
	"time"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"

	agentui "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/agents"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/worktrees"
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

type model struct {
	ctx                   context.Context //nolint:containedctx // Bubble Tea callbacks share the lifetime of the program.
	tasks                 *tui.Tasks
	area, returnArea      Area
	agents                agentui.Model
	worktrees             worktrees.Model
	width, height         int
	hasOrigin             bool
	selectionLost         bool
	notice                string
	quitting              bool
	operationCancel       context.CancelFunc
	client, targetSession string
}

type openMsg struct {
	session string
	err     error
}

func (m *model) Init() tea.Cmd { return tea.Batch(m.agents.Init(m.ctx), m.worktrees.Init(m.ctx)) }

func (m *model) activePanel() *panel.Model {
	if m.area == WorktreesArea {
		return &m.worktrees.Panel
	}

	return &m.agents.Panel
}

func (m *model) busy() bool { return m.operationCancel != nil || m.worktrees.Busy() }

func (m *model) updatePanels() {
	width, rows := max(12, m.width-2), max(1, m.height-12)
	m.agents.SetSize(width, rows)
	m.worktrees.SetSize(width, rows)
}

func (m *model) beginCreate() tea.Cmd {
	source := m.worktrees.Source()

	id := m.agents.OriginID()
	if m.area == AgentsArea {
		if choice, ok := m.agents.Find(m.agents.Panel.List.SelectedID()); ok {
			if choice.Pane.Host != "" {
				m.notice = "Worktree creation is local. Choose a local conversation or worktree."
				return nil
			}

			id = choice.Agent.ID
		}
	} else if selected, ok := m.worktrees.Selected(); ok {
		source = selected.Path
	}

	data := m.agents.Local()
	pending := m.area == WorktreesArea && m.hasOrigin && data.At.IsZero() && data.Err == nil

	cmd := m.worktrees.BeginCreate(source, id, pending)
	if m.worktrees.Creating() {
		m.returnArea, m.area = m.area, WorktreesArea
		m.notice = ""
	}

	return cmd
}

func (m *model) openItem(id string) tea.Cmd {
	if id == "" || m.busy() {
		return nil
	}

	ctx, cancel := context.WithCancel(m.ctx)

	m.operationCancel = cancel
	if m.area == AgentsArea {
		choice, ok := m.agents.Find(id)
		if !ok {
			cancel()

			m.operationCancel = nil

			return nil
		}

		return m.tasks.Track(func() tea.Msg {
			ctx, stop := context.WithTimeout(ctx, 3*time.Second)
			defer stop()

			return openMsg{err: choice.Source.Open(ctx, choice.Agent.ID, choice.Pane, m.client)}
		})
	}

	item, ok := m.worktrees.Find(id)
	if !ok {
		cancel()

		m.operationCancel = nil

		return nil
	}

	m.notice = "Opening " + item.Name + "…"

	return m.tasks.Track(func() tea.Msg {
		session, err := worktree.Open(ctx, item)
		return openMsg{session: session, err: err}
	})
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // Signature required by tea.Model.
	selected := m.agents.Panel.List.SelectedID()

	var cmd tea.Cmd

	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.updatePanels()
	case tea.KeyPressMsg:
		cmd = m.handleKey(msg)
	case openMsg:
		m.operationCancel()

		m.operationCancel = nil

		switch {
		case m.quitting:
			cmd = tea.Quit
		case msg.err != nil:
			m.notice = tui.SingleLine(msg.err.Error())
		default:
			m.targetSession = msg.session
			cmd = tea.Quit
		}
	case worktrees.OpenSessionMsg:
		m.targetSession = msg.ID
		cmd = tea.Quit
	default:
		cmd = tea.Batch(m.agents.Update(m.ctx, msg), m.worktrees.Update(m.ctx, msg))
		if update, ok := msg.(agentui.StatusMsg); ok && update.Host == "" {
			m.worktrees.SetAgents(m.agents.Local(), m.agents.OriginID())
		}

		if m.quitting && !m.busy() {
			cmd = tea.Quit
		}
	}

	if selected != m.agents.Panel.List.SelectedID() {
		if _, input := message.(tea.KeyPressMsg); input {
			m.selectionLost = false
			m.notice = ""
		} else if _, ok := m.agents.Find(selected); selected != "" && !ok {
			// A refresh can remove the highlighted thread and select the first
			// row. A pending Enter must not open that replacement.
			m.selectionLost = true
		}
	}

	return m, cmd
}

func (m *model) handleKey(msg tea.KeyPressMsg) tea.Cmd {
	if msg.String() == "ctrl+c" {
		if m.busy() {
			m.quitting = true
			if m.operationCancel != nil {
				m.operationCancel()
			}

			m.worktrees.Cancel()

			return nil
		}

		return tea.Quit
	}

	if m.busy() {
		return nil
	}

	if m.worktrees.Modal() {
		creating := m.worktrees.Creating()

		cmd := m.worktrees.Update(m.ctx, msg)
		if creating && !m.worktrees.Creating() {
			m.area = m.returnArea
		}

		return cmd
	}

	switch {
	case key.Matches(msg, keys.quit):
		return tea.Quit
	case key.Matches(msg, keys.agents):
		m.area = AgentsArea
		m.notice = ""
		m.worktrees.ClearNotice()
	case key.Matches(msg, keys.worktrees):
		m.area = WorktreesArea
		m.notice = ""
		m.worktrees.ClearNotice()
	case key.Matches(msg, keys.create):
		return m.beginCreate()
	case key.Matches(msg, keys.remove) && m.area == WorktreesArea:
		m.notice = ""
		return m.worktrees.BeginRemove(m.ctx)
	case key.Matches(msg, keys.refresh) && m.area == WorktreesArea:
		return m.worktrees.Reload(m.worktrees.Panel.List.SelectedID())
	case key.Matches(msg, keys.open):
		if m.area == AgentsArea && m.selectionLost {
			m.selectionLost = false
			m.notice = "The previous conversation disappeared. Choose a pane or press Enter again."

			return nil
		}

		return m.openItem(m.activePanel().List.SelectedID())
	case key.Matches(msg, keys.jump):
		position := int(msg.String()[0] - '0')
		if item, ok := m.activePanel().List.Item(position); ok {
			return m.openItem(item.ID)
		}
	default:
		if m.area == AgentsArea {
			return m.agents.Update(m.ctx, msg)
		}

		return m.worktrees.Update(m.ctx, msg)
	}

	return nil
}

// Run opens the interface and switches to the selected tmux pane or session on exit.
func Run(ctx context.Context, options Options) error {
	uiCtx, cancel := context.WithCancel(ctx)
	tasks := &tui.Tasks{}

	defer func() {
		cancel()
		tasks.Wait()
	}()

	source := options.Directory
	if resolved, err := filepath.EvalSymlinks(source); err == nil {
		source = resolved
	}

	initial := &model{
		ctx: uiCtx, tasks: tasks, client: options.Client, area: options.Area, width: 100, height: 30, hasOrigin: options.Pane != "",
		agents: agentui.New(options.Pane), worktrees: worktrees.New(options.Root, source, tasks),
	}

	defer initial.agents.Close()

	initial.updatePanels()
	result, err := tea.NewProgram(initial, tea.WithContext(uiCtx), tea.WithoutSignalHandler()).Run()

	cancel()

	if err != nil {
		return fmt.Errorf("run status TUI: %w", err)
	}

	if final, ok := result.(*model); ok && final.targetSession != "" {
		if err := tmux.SwitchSession(ctx, final.targetSession, options.Client); err != nil {
			return fmt.Errorf("open worktree session: %w", err)
		}
	}

	return nil
}
