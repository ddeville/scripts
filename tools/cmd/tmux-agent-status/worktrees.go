package main

import (
	"slices"

	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

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

func (m *model) loadTreeStatus() tea.Cmd {
	m.treeGeneration++
	m.nextStatus = min(4, len(m.trees))
	m.sessionsReady = false
	generation := m.treeGeneration

	commands := make([]tea.Cmd, 0, 1+m.nextStatus)

	commands = append(commands, func() tea.Msg {
		sessions, err := tmux.ListSessions(m.ctx)
		return treeSessionsMsg{sessions: sessions, generation: generation, err: err}
	})
	for i := range m.nextStatus {
		commands = append(commands, m.treeStatusCommand(i))
	}

	return tea.Batch(commands...)
}

func (m *model) treeStatusCommand(index int) tea.Cmd {
	path, generation := m.trees[index].Path, m.treeGeneration

	return func() tea.Msg {
		changes, err := git.StatusShort(m.ctx, path)
		return treeStatusMsg{path: path, changes: changes, generation: generation, err: err}
	}
}

func (m *model) reloadWorktrees(path string) tea.Cmd {
	if m.loading {
		return nil
	}

	m.loading = true

	return func() tea.Msg {
		items, err := worktree.Discover(m.root)
		return treeLoadedMsg{items: items, path: path, err: err}
	}
}

func (m *model) updateTreeList(path string) {
	items := make([]tui.ListItem, 0, len(m.trees))
	for _, item := range m.trees {
		style, state, _ := worktreeStateStyle(item.Status)
		items = append(items, tui.ListItem{
			ID: item.Path, Group: item.Repo, Title: item.Name, Subtitle: item.Branch, Status: state, StatusStyle: style,
		})
	}

	m.worktreeView.list.SetItems(items, path)
	m.updateWorktreeDetails()
}

func (m *model) selectedWorktree() (worktree.Info, bool) {
	path := m.worktreeView.list.SelectedID()

	index := slices.IndexFunc(m.trees, func(item worktree.Info) bool { return item.Path == path })
	if index < 0 {
		return worktree.Info{}, false
	}

	return m.trees[index], true
}

func (m *model) updateWorktreeDetails() {
	m.worktreeView.details.SetContent(m.worktreeDetails(m.worktreeView.details.Width()))
}

func (m *model) updateWorktrees(message tea.Msg) tea.Cmd {
	var cmd tea.Cmd

	selected := m.worktreeView.list.SelectedID()

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
		cmd = m.loadTreeStatus()
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
			cmd = m.treeStatusCommand(m.nextStatus)
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
	}

	m.updateTreeList(selected)

	return cmd
}

func (m *model) openWorktree(path string) tea.Cmd {
	index := slices.IndexFunc(m.trees, func(item worktree.Info) bool { return item.Path == path })
	if index < 0 || m.busy {
		return nil
	}

	item := m.trees[index]
	ctx := m.beginOperation()
	m.notice = "Opening " + item.Name + "…"

	return func() tea.Msg {
		id, err := worktree.Open(ctx, item)
		return openMsg{session: id, err: err}
	}
}
