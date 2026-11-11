// Package worktrees manages the Worktrees section and its create/remove forms.
package worktrees

import (
	"context"
	"path/filepath"
	"slices"
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

// Model owns worktree discovery, Git status, sessions, and management forms.
type Model struct {
	Panel                  panel.Model
	root, source           string
	width, rows            int
	trees                  []worktree.Info
	changes                map[string]string
	treeGeneration         uint64
	nextStatus             int
	sessionsReady, loading bool
	treeError, notice      string
	data                   agents.Snapshot
	originThread           string
	create                 *createForm
	remove                 *removeForm
	planVersion            uint64
	operationCancel        context.CancelFunc
}

// OpenSessionMsg asks the app to close the popup and switch to a created session.
type OpenSessionMsg struct{ ID string }

// New discovers worktrees before asynchronous status collection begins.
func New(root, source string) Model {
	m := Model{Panel: panel.New(), root: root, source: source, changes: map[string]string{}}

	items, err := worktree.Discover(root)
	if err != nil {
		m.treeError = err.Error()
	}

	m.trees = items
	m.updateTreeList("")

	for _, item := range items {
		if source == item.Path || strings.HasPrefix(source, item.Path+string(filepath.Separator)) {
			m.Panel.List.SelectID(item.Path)
			break
		}
	}

	return m
}

// Init starts asynchronous Git status and tmux session discovery.
func (m *Model) Init(ctx context.Context) tea.Cmd { return m.loadTreeStatus(ctx) }

// Source returns the fallback creation directory, updated if its checkout is removed.
func (m *Model) Source() string { return m.source }

// Busy reports whether a create or remove operation is running.
func (m *Model) Busy() bool { return m.operationCancel != nil }

// Cancel interrupts an operation; Update still handles its eventual cleanup result.
func (m *Model) Cancel() {
	if m.operationCancel != nil {
		m.operationCancel()
	}
}

// Modal reports whether a form is handling keyboard input.
func (m *Model) Modal() bool { return m.create != nil || m.remove != nil }

// Creating reports whether the creation flow is active, including its thread chooser.
func (m *Model) Creating() bool { return m.create != nil }

// ClearNotice dismisses the previous operation's message when switching sections.
func (m *Model) ClearNotice() { m.notice = "" }

func (m *Model) beginOperation(ctx context.Context) context.Context {
	ctx, cancel := context.WithCancel(ctx)
	m.operationCancel = cancel

	return ctx
}

func (m *Model) finishOperation() {
	m.operationCancel()
	m.operationCancel = nil
}

// SetAgents updates the fork chooser and resolves a pending originating thread.
func (m *Model) SetAgents(data agents.Snapshot, origin string) {
	m.data, m.originThread = data, origin
	if data.Err != nil {
		if m.create != nil {
			m.create.originPending = false
		}

		return
	}

	m.updateThreadChoices()
}

// SetSize sizes the section and any active form to the shared content area.
func (m *Model) SetSize(width, rows int) {
	m.width, m.rows = width, rows
	m.Panel.SetSize(width, rows)
	m.updateWorktreeDetails()
	m.updateRemovalDetails()

	if m.create != nil {
		m.create.setWidth(width + 2)
		m.updateThreadChoices()
	}
}

// Update handles section input and applies discovery, status, and form results.
func (m *Model) Update(ctx context.Context, message tea.Msg) tea.Cmd {
	var cmd tea.Cmd

	selected := m.Panel.List.SelectedID()

	switch msg := message.(type) {
	case treeLoadedMsg:
		m.loading = false
		if msg.err != nil {
			m.treeError = msg.err.Error()
			return nil
		}

		m.trees = msg.items
		m.changes = map[string]string{}
		m.treeError = ""
		selected = msg.path
		cmd = m.loadTreeStatus(ctx)
	case treeStatusMsg:
		if msg.generation != m.treeGeneration {
			return nil
		}

		index := slices.IndexFunc(m.trees, func(item worktree.Info) bool { return item.Path == msg.path })
		if index >= 0 {
			item := &m.trees[index]
			item.Status = "clean"

			m.changes[msg.path] = msg.changes
			if msg.changes != "" {
				item.Status = "dirty"
			}

			if msg.err != nil {
				item.Status, item.StatusError = "unknown", msg.err.Error()
			}
		}

		if m.nextStatus < len(m.trees) {
			cmd = m.treeStatusCommand(ctx, m.nextStatus)
			m.nextStatus++
		}
	case treeSessionsMsg:
		if msg.generation != m.treeGeneration {
			return nil
		}

		m.sessionsReady = true
		if msg.err != nil {
			m.treeError = msg.err.Error()
		} else {
			for i := range m.trees {
				m.trees[i].Session = worktree.MatchSession(m.trees[i], msg.sessions)
			}
		}
	case createdMsg:
		m.finishOperation()
		return m.created(msg)
	case removedMsg:
		m.finishOperation()
		return m.removed(msg)
	case plannedMsg:
		if m.remove != nil && msg.version == m.planVersion {
			m.remove.plan, m.remove.err, m.remove.checking = msg.plan, msg.err, false
			m.updateRemovalDetails()
		}

		return nil
	case tea.KeyPressMsg:
		if m.Busy() {
			return nil
		}

		if m.create != nil {
			return m.createKey(ctx, msg)
		}

		if m.remove != nil {
			return m.removeKey(ctx, msg)
		}

		cmd := m.Panel.Update(msg)
		m.updateWorktreeDetails()

		return cmd
	default:
		if m.create != nil && !m.create.picking {
			return m.create.updateInput(message)
		}

		return nil
	}

	m.updateTreeList(selected)

	return cmd
}

type (
	treeLoadedMsg struct {
		items []worktree.Info
		path  string
		err   error
	}
	treeStatusMsg struct {
		path, changes string
		generation    uint64
		err           error
	}
	treeSessionsMsg struct {
		sessions   []tmux.Session
		generation uint64
		err        error
	}
)

func (m *Model) loadTreeStatus(ctx context.Context) tea.Cmd {
	m.treeGeneration++
	m.nextStatus = min(4, len(m.trees))
	m.sessionsReady = false
	generation := m.treeGeneration

	commands := make([]tea.Cmd, 0, 1+m.nextStatus)

	commands = append(commands, func() tea.Msg {
		sessions, err := tmux.ListSessions(ctx)
		return treeSessionsMsg{sessions: sessions, generation: generation, err: err}
	})
	for i := range m.nextStatus {
		commands = append(commands, m.treeStatusCommand(ctx, i))
	}

	return tea.Batch(commands...)
}

func (m *Model) treeStatusCommand(ctx context.Context, index int) tea.Cmd {
	path, generation := m.trees[index].Path, m.treeGeneration

	return func() tea.Msg {
		changes, err := git.StatusShort(ctx, path)
		return treeStatusMsg{path: path, changes: changes, generation: generation, err: err}
	}
}

// Reload refreshes worktrees and preserves the requested selection.
func (m *Model) Reload(path string) tea.Cmd {
	if m.loading {
		return nil
	}

	m.loading = true

	return func() tea.Msg {
		items, err := worktree.Discover(m.root)
		return treeLoadedMsg{items: items, path: path, err: err}
	}
}

func (m *Model) updateTreeList(path string) {
	items := make([]tui.ListItem, 0, len(m.trees))
	for _, item := range m.trees {
		style, state, _ := worktreeStateStyle(item.Status)
		items = append(items, tui.ListItem{
			ID: item.Path, Group: item.Repo, Title: item.Name, Subtitle: item.Branch, Status: state, StatusStyle: style,
		})
	}

	m.Panel.List.SetItems(items, path)
	m.updateWorktreeDetails()
}

// Selected returns the checkout selected in the worktree list.
func (m *Model) Selected() (worktree.Info, bool) {
	return m.Find(m.Panel.List.SelectedID())
}

// Find locates a managed checkout by path.
func (m *Model) Find(path string) (worktree.Info, bool) {
	index := slices.IndexFunc(m.trees, func(item worktree.Info) bool { return item.Path == path })
	if index < 0 {
		return worktree.Info{}, false
	}

	return m.trees[index], true
}

func (m *Model) updateWorktreeDetails() {
	m.Panel.Details.SetContent(m.worktreeDetails(m.Panel.Details.Width()))
}
