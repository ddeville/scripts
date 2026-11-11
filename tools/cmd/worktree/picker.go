package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"charm.land/bubbles/v2/textinput"
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
	index int
	state string
	err   error
}

type sessionsMsg struct {
	sessions []tmux.Session
	err      error
}

type model struct {
	ctx           context.Context //nolint:containedctx // Bubble Tea callbacks have no context parameter; commands share the picker lifetime.
	items         []worktree
	visible       []int
	index, next   int
	width, height int
	filter        textinput.Model
	view          viewport.Model
	sessionsReady bool
	notice        string
	opening       bool
	target        string
	root          string
}

func (m *model) Init() tea.Cmd {
	commands := make([]tea.Cmd, 0, 1+m.next)
	commands = append(commands, func() tea.Msg {
		sessions, err := tmux.ListSessions(m.ctx)
		return sessionsMsg{sessions: sessions, err: err}
	})

	for i := range m.next {
		commands = append(commands, m.statusCommand(i))
	}

	return tea.Batch(commands...)
}

func (m *model) statusCommand(index int) tea.Cmd {
	path := m.items[index].Path

	return func() tea.Msg {
		state, err := git.Status(m.ctx, path)
		return statusMsg{index: index, state: state, err: err}
	}
}

func (m *model) refilter() {
	selected := -1
	if len(m.visible) > 0 {
		selected = m.visible[m.index]
	}

	m.visible = nil
	terms := strings.Fields(strings.ToLower(m.filter.Value()))

	for i, item := range m.items {
		text := strings.ToLower(strings.Join([]string{item.Repo, item.Name, item.Branch, item.Path, item.Session.Name}, " "))
		matches := true

		for _, term := range terms {
			if !strings.Contains(text, term) {
				matches = false
				break
			}
		}

		if matches {
			m.visible = append(m.visible, i)
		}
	}

	m.index = max(0, slices.Index(m.visible, selected))
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) { //nolint:ireturn // This signature is required by tea.Model.
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.setSize()
	case statusMsg:
		m.items[msg.index].Status = msg.state
		if msg.err != nil {
			m.items[msg.index].StatusError = msg.err.Error()
		}

		if m.next < len(m.items) {
			cmd = m.statusCommand(m.next)
			m.next++
		}
	case sessionsMsg:
		m.sessionsReady = true
		if msg.err != nil {
			m.notice = msg.err.Error()
		} else {
			for i := range m.items {
				m.items[i].Session = matchSession(m.items[i], msg.sessions)
			}

			m.refilter()
		}
	case openMsg:
		m.opening = false
		if msg.err != nil {
			m.notice = msg.err.Error()
		} else {
			m.target = msg.id
			return m, tea.Quit
		}
	case tea.KeyPressMsg:
		cmd = m.handleKey(msg)
	default:
		m.filter, cmd = m.filter.Update(msg)
	}

	m.renderList()

	return m, cmd
}

func (m *model) handleKey(msg tea.KeyPressMsg) tea.Cmd {
	key := msg.String()
	if key == "ctrl+c" {
		return tea.Quit
	}

	if key == "esc" {
		if m.filter.Focused() {
			m.filter.Blur()
			return nil
		}

		return tea.Quit
	}

	if m.opening {
		return nil
	}

	switch {
	case key == "enter":
		return m.open()
	case key == "up" || key == "ctrl+p" || key == "k" && !m.filter.Focused():
		m.move(-1)
	case key == "down" || key == "ctrl+n" || key == "j" && !m.filter.Focused():
		m.move(1)
	case m.filter.Focused():
		var cmd tea.Cmd

		m.filter, cmd = m.filter.Update(msg)
		m.refilter()

		return cmd
	case key == "q":
		return tea.Quit
	case key == "/":
		return m.filter.Focus()
	case key == "home" || key == "g":
		m.index = 0
	case key == "end" || key == "G":
		m.index = max(0, len(m.visible)-1)
	case key == "pgup":
		m.index = max(0, m.index-max(1, m.view.Height()-2))
	case key == "pgdown":
		m.index = min(max(0, len(m.visible)-1), m.index+max(1, m.view.Height()-2))
	case len(key) == 1 && key[0] >= '0' && key[0] <= '9':
		index := int(key[0] - '0')
		if index < len(m.visible) {
			m.index = index
			return m.open()
		}
	}

	return nil
}

func (m *model) move(delta int) {
	if len(m.visible) > 0 {
		m.index = (m.index + delta + len(m.visible)) % len(m.visible)
	}
}

func (m *model) setSize() {
	m.filter.SetWidth(max(1, m.width-24))
	m.view.SetWidth(max(1, m.width-2))
	m.view.SetHeight(max(1, m.height-6))
}

func (m *model) open() tea.Cmd {
	if len(m.visible) == 0 {
		return nil
	}

	item := m.items[m.visible[m.index]]
	m.opening, m.notice = true, ""

	return func() tea.Msg {
		id, err := ensureSession(m.ctx, item, sessionOptions{})
		return openMsg{id: id, err: err}
	}
}

func runPicker(ctx context.Context, root, client string) error {
	root, err := filepath.Abs(root)
	if err != nil {
		return fmt.Errorf("resolve worktree directory: %w", err)
	}

	items, err := discover(root)
	if err != nil {
		return err
	}

	uiCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	initial := &model{
		ctx: uiCtx, items: items, next: min(4, len(items)), root: root,
		width: 100, height: 30, view: viewport.New(), filter: textinput.New(),
	}
	initial.filter.Prompt = "/ "
	initial.filter.Placeholder = "filter"
	initial.filter.CharLimit = 256
	initial.setSize()
	initial.refilter()

	cwd, _ := os.Getwd()
	cwd = canonical(cwd)

	for i, item := range items {
		if cwd == item.Path || strings.HasPrefix(cwd, item.Path+string(filepath.Separator)) {
			initial.index = i
			break
		}
	}

	initial.renderList()
	result, err := tea.NewProgram(initial, tea.WithContext(uiCtx), tea.WithoutSignalHandler()).Run()

	cancel()

	if err != nil {
		return fmt.Errorf("run worktree picker: %w", err)
	}

	if final, ok := result.(*model); ok && final.target != "" {
		if err := tmux.SwitchSession(ctx, final.target, client); err != nil {
			return fmt.Errorf("switch session: %w", err)
		}
	}

	return nil
}
