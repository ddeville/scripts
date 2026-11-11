package main

import (
	"cmp"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

type createForm struct {
	inputs                         []textinput.Model
	focus                          int
	noTmux, picking, originPending bool
	forkID, forkTitle, message     string
	choices                        tui.List
	returnArea                     area
}
type removeForm struct {
	item                 worktree.Info
	keepBranch, checking bool
	offset               int
	plan                 worktree.Removal
	err                  error
}
type (
	createdMsg struct {
		item worktree.Info
		id   string
		err  error
	}
	plannedMsg struct {
		plan    worktree.Removal
		version uint64
		err     error
	}
	removedMsg struct {
		plan worktree.Removal
		err  error
	}
)

func (m *model) beginCreate() tea.Cmd {
	if m.loading {
		return nil
	}

	source := m.source

	id := m.originThread
	if m.area == agentsArea {
		id = m.selected
	} else if selected, ok := m.selectedWorktree(); ok {
		source = selected.Path
	}

	form := &createForm{inputs: make([]textinput.Model, 3), choices: tui.NewList(), returnArea: m.area}
	for i, placeholder := range []string{"feature-name", "Repository or worktree path", "HEAD"} {
		form.inputs[i] = textinput.New()
		form.inputs[i].Prompt = ""
		form.inputs[i].Placeholder = placeholder
		form.inputs[i].CharLimit = 4096
	}

	for _, a := range m.data.Agents {
		if a.ID == id && a.Cwd != "" {
			source, form.forkID, form.forkTitle = a.Cwd, a.ID, a.Title
			break
		}
	}

	form.originPending = m.area == worktreesArea && m.originPane != "" && m.data.At.IsZero() && m.data.Err == nil
	form.inputs[1].SetValue(source)
	form.inputs[2].SetValue("HEAD")
	form.setWidth(m.width)
	m.create, m.notice, m.area = form, "", worktreesArea
	m.updateThreadChoices()

	return form.inputs[0].Focus()
}

func (f *createForm) setWidth(width int) {
	for i := range f.inputs {
		f.inputs[i].SetWidth(max(1, width-22))
	}
}

func (f *createForm) updateInput(msg tea.Msg) tea.Cmd {
	if f.focus >= len(f.inputs) {
		return nil
	}

	before := f.inputs[f.focus].Value()

	var cmd tea.Cmd

	f.inputs[f.focus], cmd = f.inputs[f.focus].Update(msg)
	if f.focus == 1 && f.inputs[1].Value() != before {
		f.originPending = false
	}

	return cmd
}

func (m *model) updateThreadChoices() {
	form := m.create
	if form == nil {
		return
	}

	if form.originPending && !m.data.At.IsZero() {
		for _, a := range m.data.Agents {
			if a.ID == m.originThread && a.Cwd != "" {
				form.forkID, form.forkTitle = a.ID, a.Title
				form.inputs[1].SetValue(a.Cwd)

				break
			}
		}

		form.originPending = false
	}

	selected := form.choices.SelectedID()
	agents := slices.Clone(m.data.Agents)
	slices.SortStableFunc(agents, func(a, b agent) int { return cmp.Compare(a.Cwd, b.Cwd) })

	form.choices.Items = nil

	for _, a := range agents {
		if a.Cwd != "" && a.Type == AgentTypeCodex {
			form.choices.Items = append(form.choices.Items, agentRow(a))
		}
	}

	form.choices.Items = append(form.choices.Items, tui.ListItem{
		ID: "codex-picker", Group: "Other conversations", Title: "Choose in Codex", Subtitle: "Browse saved conversations when the new session opens", StatusStyle: tui.Muted,
	})
	form.choices.SelectID(selected)

	_, _, rows := m.panelDimensions(worktreesArea)
	form.choices.SetSize(max(1, m.width-6), rows)
}

func (m *model) chooseThread() tea.Cmd {
	form := m.create
	form.originPending = false

	form.picking = true
	if form.focus < len(form.inputs) {
		form.inputs[form.focus].Blur()
	}

	form.focus = len(form.inputs)

	m.updateThreadChoices()
	form.choices.SelectID(cmp.Or(form.forkID, "codex-picker"))

	return nil
}

func (m *model) threadKey(msg tea.KeyPressMsg) tea.Cmd {
	form := m.create

	switch msg.String() {
	case "esc":
		form.picking = false
	case "enter":
		id := form.choices.SelectedID()
		if id == "codex-picker" {
			form.forkID, form.forkTitle = "", ""
		} else {
			for _, a := range m.data.Agents {
				if a.ID == id {
					form.forkID, form.forkTitle = a.ID, a.Title
					form.inputs[1].SetValue(a.Cwd)

					break
				}
			}
		}

		form.picking = false
	default:
		form.choices.Move(msg)
	}

	return nil
}

func (m *model) createKey(msg tea.KeyPressMsg) tea.Cmd {
	form := m.create
	if form.picking {
		return m.threadKey(msg)
	}

	switch msg.String() {
	case "esc":
		m.area = form.returnArea
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

		form.focus = (form.focus + delta + len(form.inputs) + 2) % (len(form.inputs) + 2)
		if form.focus < len(form.inputs) {
			return form.inputs[form.focus].Focus()
		}
	case "enter":
		if form.focus == len(form.inputs) && !form.noTmux {
			return m.chooseThread()
		}

		return m.submitCreate()
	case "space":
		if form.focus == len(form.inputs)+1 {
			form.noTmux = !form.noTmux
			return nil
		}

		if form.focus == len(form.inputs) && !form.noTmux {
			return m.chooseThread()
		}

		return form.updateInput(msg)
	default:
		return form.updateInput(msg)
	}

	return nil
}

func (m *model) submitCreate() tea.Cmd {
	form := m.create

	options := worktree.CreateOptions{Name: form.inputs[0].Value(), Directory: form.inputs[1].Value(), Base: form.inputs[2].Value(), NoTmux: form.noTmux}
	if options.Name == "" || options.Directory == "" {
		form.message = "Enter a name and source directory."
		return nil
	}

	if form.originPending && !options.NoTmux {
		form.message = "Checking the current conversation…"
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

	if !options.NoTmux {
		options.Fork = form.forkID
	}

	m.busy, form.message = true, "Creating worktree…"

	return func() tea.Msg {
		item, id, err := worktree.Create(m.ctx, m.root, options)
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
		m.targetSession = msg.id
		return tea.Quit
	}

	return m.reloadWorktrees(msg.item.Path)
}

func (m *model) beginRemove() tea.Cmd {
	if m.loading {
		return nil
	}

	item, ok := m.selectedWorktree()
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
		plan, err := worktree.PlanRemoval(m.ctx, item, keep)
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

		return func() tea.Msg { return removedMsg{plan: plan, err: worktree.Remove(m.ctx, plan)} }
	}

	return nil
}

func (m *model) removed(msg removedMsg) tea.Cmd {
	m.busy, m.remove = false, nil

	m.notice = "Removed " + msg.plan.Worktree.Name
	if msg.err != nil {
		m.notice = msg.err.Error()
	} else if m.source == msg.plan.Worktree.Path || strings.HasPrefix(m.source, msg.plan.Worktree.Path+string(filepath.Separator)) {
		m.source = msg.plan.MainPath
	}

	return m.reloadWorktrees("")
}
