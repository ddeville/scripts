package main

import (
	"os"
	"path/filepath"
	"strings"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
)

type createForm struct {
	inputs  []textinput.Model
	focus   int
	noTmux  bool
	message string
}

type removeForm struct {
	item       worktree
	keepBranch bool
	checking   bool
	offset     int
	plan       removal
	err        error
}

type createdMsg struct {
	item worktree
	id   string
	err  error
}

type plannedMsg struct {
	plan    removal
	version uint64
	err     error
}

type removedMsg struct {
	plan removal
	err  error
}

func (m *model) beginCreate() tea.Cmd {
	if m.loading {
		return nil
	}

	source := m.source
	if selected, ok := m.selected(); ok {
		source = selected.Path
	}

	form := &createForm{inputs: make([]textinput.Model, 4)}
	for i, placeholder := range []string{"feature-name", "Repository or worktree path", "HEAD", "Choose a conversation in Codex"} {
		form.inputs[i] = textinput.New()
		form.inputs[i].Prompt = ""
		form.inputs[i].Placeholder = placeholder
		form.inputs[i].CharLimit = 4096
	}

	form.inputs[1].SetValue(source)
	form.inputs[2].SetValue("HEAD")
	form.setWidth(m.width)
	m.create, m.notice = form, ""

	return form.inputs[0].Focus()
}

func (f *createForm) setWidth(width int) {
	for i := range f.inputs {
		f.inputs[i].SetWidth(max(1, width-18))
	}
}

func (f *createForm) updateInput(msg tea.Msg) tea.Cmd {
	if f.focus >= len(f.inputs) {
		return nil
	}

	var cmd tea.Cmd

	f.inputs[f.focus], cmd = f.inputs[f.focus].Update(msg)

	return cmd
}

func (m *model) createKey(msg tea.KeyPressMsg) tea.Cmd {
	form := m.create

	switch msg.String() {
	case "esc":
		m.create = nil
		return nil
	case "tab", "shift+tab", "down", "up":
		delta := 1
		if msg.String() == "shift+tab" || msg.String() == "up" {
			delta = -1
		}

		if form.focus < len(form.inputs) {
			form.inputs[form.focus].Blur()
		}

		form.focus = (form.focus + delta + len(form.inputs) + 1) % (len(form.inputs) + 1)
		if form.focus < len(form.inputs) {
			return form.inputs[form.focus].Focus()
		}
	case "enter":
		return m.submitCreate()
	case "space":
		if form.focus == len(form.inputs) {
			form.noTmux = !form.noTmux
			return nil
		}

		return form.updateInput(msg)
	default:
		return form.updateInput(msg)
	}

	return nil
}

func (m *model) submitCreate() tea.Cmd {
	form := m.create

	options := createOptions{
		Name: form.inputs[0].Value(), Directory: form.inputs[1].Value(), Base: form.inputs[2].Value(),
	}
	if options.Name == "" || options.Directory == "" {
		form.message = "Enter a name and source directory."
		return nil
	}

	if home, err := os.UserHomeDir(); err == nil {
		if options.Directory == "~" {
			options.Directory = home
		} else if relative, ok := strings.CutPrefix(options.Directory, "~/"); ok {
			options.Directory = filepath.Join(home, relative)
		}
	}

	if !filepath.IsAbs(options.Directory) {
		options.Directory = filepath.Join(m.source, options.Directory)
	}

	fork, noTmux := strings.TrimSpace(form.inputs[3].Value()), form.noTmux
	if fork != "" && noTmux {
		form.message = "Enable the tmux session to fork a Codex conversation."
		return nil
	}

	m.busy, form.message = true, "Creating worktree…"

	return func() tea.Msg {
		item, id, err := createWorkspace(m.ctx, m.root, options, fork, noTmux)
		return createdMsg{item: item, id: id, err: err}
	}
}

func (m *model) created(msg createdMsg) tea.Cmd {
	m.busy = false
	if msg.err != nil && msg.item.Path == "" {
		m.create.message = msg.err.Error()
		return nil
	}

	m.create = nil

	m.notice = "Created " + msg.item.Name
	if msg.err != nil {
		m.notice = msg.err.Error()
	} else if msg.id != "" {
		m.target = msg.id
		return tea.Quit
	}

	return m.reload(msg.item.Path)
}

func (m *model) beginRemove() tea.Cmd {
	if m.loading {
		return nil
	}

	item, ok := m.selected()
	if !ok {
		return nil
	}

	m.remove, m.notice = &removeForm{item: item}, ""

	return m.planRemove()
}

func (m *model) planRemove() tea.Cmd {
	m.planVersion++
	m.remove.checking = true
	item, keep, version := m.remove.item, m.remove.keepBranch, m.planVersion

	return func() tea.Msg {
		plan, err := planRemoval(m.ctx, item, keep)
		return plannedMsg{plan: plan, version: version, err: err}
	}
}

func (m *model) removeKey(msg tea.KeyPressMsg) tea.Cmd {
	switch msg.String() {
	case "esc", "n":
		m.remove = nil
	case "k":
		m.remove.keepBranch = !m.remove.keepBranch
		return m.planRemove()
	case "down", "j":
		m.remove.offset++
	case "up":
		m.remove.offset = max(0, m.remove.offset-1)
	case "y":
		if m.remove.checking || m.remove.err != nil {
			return nil
		}

		plan := m.remove.plan
		m.busy = true

		return func() tea.Msg {
			return removedMsg{plan: plan, err: removeWorktree(m.ctx, plan)}
		}
	}

	return nil
}
