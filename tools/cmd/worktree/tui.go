package main

import (
	"context"
	"fmt"
	"path/filepath"
	"slices"
	"strings"

	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

type openMsg struct {
	id  string
	err error
}

type statusMsg struct {
	path, changes string
	generation    uint64
	err           error
}

type sessionsMsg struct {
	sessions   []tmux.Session
	generation uint64
	err        error
}

type loadedMsg struct {
	items []worktree
	path  string
	err   error
}

type model struct {
	ctx           context.Context //nolint:containedctx // Bubble Tea callbacks have no context parameter; commands share the UI lifetime.
	items         []worktree
	index, next   int
	width, height int
	view          viewport.Model
	changes       map[string]string
	generation    uint64
	sessionsReady bool
	loading       bool
	notice        string
	busy          bool
	target        string
	root, source  string
	create        *createForm
	remove        *removeForm
	planVersion   uint64
}

func (m *model) Init() tea.Cmd { return m.loadStatus() }

func (m *model) loadStatus() tea.Cmd {
	m.generation++
	m.next = min(4, len(m.items))
	m.sessionsReady = false
	generation := m.generation
	commands := make([]tea.Cmd, 0, 1+m.next)
	commands = append(commands, func() tea.Msg {
		sessions, err := tmux.ListSessions(m.ctx)
		return sessionsMsg{sessions: sessions, generation: generation, err: err}
	})

	for i := range m.next {
		commands = append(commands, m.statusCommand(i))
	}

	return tea.Batch(commands...)
}

func (m *model) statusCommand(index int) tea.Cmd {
	path, generation := m.items[index].Path, m.generation

	return func() tea.Msg {
		changes, err := git.StatusShort(m.ctx, path)
		return statusMsg{path: path, changes: changes, generation: generation, err: err}
	}
}

func (m *model) selected() (worktree, bool) {
	if len(m.items) == 0 {
		return worktree{}, false
	}

	return m.items[m.index], true
}

func (m *model) selectPath(path string) {
	m.index = max(0, slices.IndexFunc(m.items, func(item worktree) bool { return item.Path == path }))
}

func (m *model) reload(path string) tea.Cmd {
	if m.loading {
		return nil
	}

	m.loading = true

	return func() tea.Msg {
		items, err := discover(m.root)
		return loadedMsg{items: items, path: path, err: err}
	}
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // This signature is required by tea.Model.
	var cmd tea.Cmd

	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.setSize()
	case loadedMsg:
		m.loading = false
		if msg.err != nil {
			m.notice = msg.err.Error()
			break
		}

		m.items = msg.items
		m.changes = map[string]string{}
		m.selectPath(msg.path)
		cmd = m.loadStatus()
	case statusMsg:
		if msg.generation != m.generation {
			break
		}

		index := slices.IndexFunc(m.items, func(item worktree) bool { return item.Path == msg.path })
		if index >= 0 {
			item := &m.items[index]
			item.Status = "clean"

			m.changes[msg.path] = msg.changes
			if msg.changes != "" {
				item.Status = "dirty"
			}

			if msg.err != nil {
				item.Status, item.StatusError = "unknown", msg.err.Error()
			}
		}

		if m.next < len(m.items) {
			cmd = m.statusCommand(m.next)
			m.next++
		}
	case sessionsMsg:
		if msg.generation != m.generation {
			break
		}

		m.sessionsReady = true
		if msg.err != nil {
			m.notice = msg.err.Error()
		} else {
			for i := range m.items {
				m.items[i].Session = matchSession(m.items[i], msg.sessions)
			}
		}
	case openMsg:
		m.busy = false
		if msg.err != nil {
			m.notice = msg.err.Error()
		} else {
			m.target = msg.id
			return m, tea.Quit
		}
	case createdMsg:
		cmd = m.created(msg)
	case plannedMsg:
		if m.remove != nil && msg.version == m.planVersion {
			m.remove.plan, m.remove.err, m.remove.checking = msg.plan, msg.err, false
		}
	case removedMsg:
		m.busy, m.remove = false, nil

		m.notice = "Removed " + msg.plan.Worktree.Name
		if msg.err != nil {
			m.notice = msg.err.Error()
		} else if m.source == msg.plan.Worktree.Path || strings.HasPrefix(m.source, msg.plan.Worktree.Path+string(filepath.Separator)) {
			m.source = msg.plan.main
		}

		cmd = m.reload("")
	case tea.KeyPressMsg:
		cmd = m.handleKey(msg)
	default:
		if m.create != nil {
			cmd = m.create.updateInput(msg)
		}
	}

	m.renderList()

	return m, cmd
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

	key := msg.String()

	switch {
	case key == "enter":
		return m.open()
	case key == "up" || key == "ctrl+p" || key == "k":
		m.move(-1)
	case key == "down" || key == "ctrl+n" || key == "j":
		m.move(1)
	case key == "q" || key == "esc":
		return tea.Quit
	case key == "n":
		return m.beginCreate()
	case key == "d":
		return m.beginRemove()
	case key == "r":
		item, _ := m.selected()
		return m.reload(item.Path)
	case key == "home" || key == "g":
		m.index = 0
	case key == "end" || key == "G":
		m.index = max(0, len(m.items)-1)
	case key == "pgup":
		m.index = max(0, m.index-max(1, m.view.Height()/2))
	case key == "pgdown":
		m.index = min(max(0, len(m.items)-1), m.index+max(1, m.view.Height()/2))
	case len(key) == 1 && key[0] >= '0' && key[0] <= '9':
		index := int(key[0] - '0')
		if index < len(m.items) {
			m.index = index
			return m.open()
		}
	}

	return nil
}

func (m *model) move(delta int) {
	if len(m.items) > 0 {
		m.index = (m.index + delta + len(m.items)) % len(m.items)
	}
}

func (m *model) setSize() {
	left, _ := m.columns()
	m.view.SetWidth(left)
	m.view.SetHeight(max(1, m.height-6))

	if m.create != nil {
		m.create.setWidth(m.width)
	}
}

func (m *model) open() tea.Cmd {
	item, ok := m.selected()
	if !ok {
		return nil
	}

	m.busy, m.notice = true, "Opening "+item.Name+"…"

	return func() tea.Msg {
		id, err := ensureSession(m.ctx, item, sessionOptions{})
		return openMsg{id: id, err: err}
	}
}

func runTUI(ctx context.Context, root, source, client string) error {
	items, err := discover(root)
	if err != nil {
		return err
	}

	uiCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	initial := &model{
		ctx: uiCtx, items: items, root: root, source: canonical(source), changes: map[string]string{},
		width: 100, height: 30, view: viewport.New(),
	}
	initial.setSize()

	for i, item := range items {
		if initial.source == item.Path || strings.HasPrefix(initial.source, item.Path+string(filepath.Separator)) {
			initial.index = i
			break
		}
	}

	initial.renderList()
	result, err := tea.NewProgram(initial, tea.WithContext(uiCtx), tea.WithoutSignalHandler()).Run()

	cancel()

	if err != nil {
		return fmt.Errorf("run worktree UI: %w", err)
	}

	if final, ok := result.(*model); ok && final.target != "" {
		if err := tmux.SwitchSession(ctx, final.target, client); err != nil {
			return fmt.Errorf("switch session: %w", err)
		}
	}

	return nil
}
