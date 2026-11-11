// Package ui presents the unified Agents and Worktrees terminal interface.
package ui

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
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
	ctx                       context.Context //nolint:containedctx // Bubble Tea callbacks share the lifetime of the program.
	area, returnArea          Area
	agents                    agentui.Model
	worktrees                 worktrees.Model
	width, height             int
	hasOrigin                 bool
	notice                    string
	quitting                  bool
	operationCancel           context.CancelFunc
	targetPane, targetSession string
}

type openMsg struct {
	pane, session string
	err           error
}

var errStaleStatus = errors.New("status is stale; wait for a fresh update")

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
		id = m.agents.Panel.List.SelectedID()
	} else if selected, ok := m.worktrees.Selected(); ok {
		source = selected.Path
	}

	data := m.agents.Snapshot()
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
		data := m.agents.Snapshot()

		return func() tea.Msg {
			if data.Err != nil || time.Since(data.At) > 10*time.Second {
				return openMsg{err: errStaleStatus}
			}

			ctx, stop := context.WithTimeout(ctx, time.Second)
			defer stop()

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

	item, ok := m.worktrees.Find(id)
	if !ok {
		cancel()

		m.operationCancel = nil

		return nil
	}

	m.notice = "Opening " + item.Name + "…"

	return func() tea.Msg {
		session, err := worktree.Open(ctx, item)
		return openMsg{session: session, err: err}
	}
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // Signature required by tea.Model.
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.updatePanels()
	case tea.KeyPressMsg:
		return m, m.handleKey(msg)
	case openMsg:
		m.operationCancel()

		m.operationCancel = nil
		if m.quitting {
			return m, tea.Quit
		}

		if msg.err != nil {
			m.notice = tui.SingleLine(msg.err.Error())
			return m, nil
		}

		m.targetPane, m.targetSession = msg.pane, msg.session

		return m, tea.Quit
	case worktrees.OpenSessionMsg:
		m.targetSession = msg.ID
		return m, tea.Quit
	default:
		selected := m.agents.Panel.List.SelectedID()

		cmd := tea.Batch(m.agents.Update(m.ctx, msg), m.worktrees.Update(m.ctx, msg))
		if selected != m.agents.Panel.List.SelectedID() {
			m.notice = ""
		}

		if _, ok := msg.(agents.Snapshot); ok {
			m.worktrees.SetAgents(m.agents.Snapshot(), m.agents.OriginID())
		}

		if m.quitting && !m.busy() {
			return m, tea.Quit
		}

		return m, cmd
	}

	return m, nil
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
	case key.Matches(msg, agentui.Keys.NextFilter, agentui.Keys.PreviousFilter, agentui.Keys.Attention) && m.area == AgentsArea:
		before := m.agents.Panel.List.SelectedID()

		cmd := m.agents.Filter(m.ctx, msg)
		if before != m.agents.Panel.List.SelectedID() {
			m.notice = ""
		}

		return cmd
	case key.Matches(msg, keys.open):
		return m.openItem(m.activePanel().List.SelectedID())
	case key.Matches(msg, keys.jump):
		position := int(msg.String()[0] - '0')
		if item, ok := m.activePanel().List.Item(position); ok {
			return m.openItem(item.ID)
		}
	default:
		if m.area == AgentsArea {
			before := m.agents.Panel.List.SelectedID()

			cmd := m.agents.Navigate(m.ctx, msg)
			if before != m.agents.Panel.List.SelectedID() {
				m.notice = ""
			}

			return cmd
		}

		return m.worktrees.Navigate(msg)
	}

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
		ctx: uiCtx, area: options.Area, width: 100, height: 30, hasOrigin: options.Pane != "",
		agents: agentui.New(options.Pane), worktrees: worktrees.New(options.Root, source),
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
