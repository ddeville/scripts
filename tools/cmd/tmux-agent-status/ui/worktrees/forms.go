package worktrees

import (
	"cmp"
	"context"
	"os"
	"path/filepath"
	"strings"

	"charm.land/bubbles/v2/textinput"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	agentui "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/agents"
	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

type createForm struct {
	inputs                         []textinput.Model
	focus                          int
	noTmux, picking, originPending bool
	forkID, forkTitle, message     string
	choices                        tui.List
}
type removeForm struct {
	item                 worktree.Info
	keepBranch, checking bool
	view                 viewport.Model
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

// BeginCreate opens the form using the source and thread chosen by the app.
func (m *Model) BeginCreate(source, id string, pending bool) tea.Cmd {
	if m.loading {
		return nil
	}

	form := &createForm{inputs: make([]textinput.Model, 3), choices: tui.NewList()}
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

	form.originPending = pending
	form.inputs[1].SetValue(source)
	form.inputs[2].SetValue("HEAD")
	form.setWidth(m.width + 2)
	m.create, m.notice = form, ""
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

func (m *Model) updateThreadChoices() {
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

	items := make([]tui.ListItem, 0, len(m.data.Agents)+1)

	for _, a := range m.data.Agents {
		if a.Cwd != "" && a.Type == agents.Codex {
			items = append(items, agentui.Row(a))
		}
	}

	items = append(items, tui.ListItem{
		ID: "codex-picker", Group: "Other conversations", Title: "Choose in Codex", Subtitle: "Browse saved conversations when the new session opens", StatusStyle: tui.Muted,
	})
	form.choices.SetItems(items, selected)

	form.choices.SetSize(max(1, m.width-4), m.rows)
}

func (m *Model) chooseThread() tea.Cmd {
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

func (m *Model) threadKey(msg tea.KeyPressMsg) tea.Cmd {
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

func (m *Model) createKey(ctx context.Context, msg tea.KeyPressMsg) tea.Cmd {
	form := m.create
	if form.picking {
		return m.threadKey(msg)
	}

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

		form.focus = (form.focus + delta + len(form.inputs) + 2) % (len(form.inputs) + 2)
		if form.focus < len(form.inputs) {
			return form.inputs[form.focus].Focus()
		}
	case "enter":
		if form.focus == len(form.inputs) && !form.noTmux {
			return m.chooseThread()
		}

		return m.submitCreate(ctx)
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

func (m *Model) submitCreate(ctx context.Context) tea.Cmd {
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

	ctx = m.beginOperation(ctx)
	form.message = "Creating worktree…"

	return m.tasks.Track(func() tea.Msg {
		item, id, err := worktree.Create(ctx, m.root, options)
		return createdMsg{item: item, id: id, err: err}
	})
}

func (m *Model) created(msg createdMsg) tea.Cmd {
	if msg.err != nil && msg.item.Path == "" {
		m.create.message = msg.err.Error()
		return nil
	}

	m.create = nil

	m.notice = "Created " + msg.item.Name
	if msg.err != nil {
		m.notice = msg.err.Error()
	} else if msg.id != "" {
		return func() tea.Msg { return OpenSessionMsg{ID: msg.id} }
	}

	return m.Reload(msg.item.Path)
}

// BeginRemove opens the removal preview for the selected checkout.
func (m *Model) BeginRemove(ctx context.Context) tea.Cmd {
	if m.loading {
		return nil
	}

	item, ok := m.Selected()
	if !ok {
		return nil
	}

	m.remove, m.notice = &removeForm{item: item, view: panel.NewViewport()}, ""

	return m.planRemove(ctx)
}

func (m *Model) planRemove(ctx context.Context) tea.Cmd {
	m.planVersion++
	m.remove.checking = true
	m.updateRemovalDetails()
	item, keep, version := m.remove.item, m.remove.keepBranch, m.planVersion

	return func() tea.Msg {
		plan, err := worktree.PlanRemoval(ctx, item, keep)
		return plannedMsg{plan: plan, version: version, err: err}
	}
}

func (m *Model) removeKey(ctx context.Context, msg tea.KeyPressMsg) tea.Cmd {
	switch msg.String() {
	case "esc", "n":
		m.remove = nil
	case "k":
		m.remove.keepBranch = !m.remove.keepBranch
		return m.planRemove(ctx)
	case "y":
		if m.remove.checking || m.remove.err != nil {
			return nil
		}

		plan := m.remove.plan
		ctx = m.beginOperation(ctx)
		m.updateRemovalDetails()

		return m.tasks.Track(func() tea.Msg { return removedMsg{plan: plan, err: worktree.Remove(ctx, plan)} })
	default:
		var cmd tea.Cmd

		m.remove.view, cmd = m.remove.view.Update(msg)

		return cmd
	}

	return nil
}

func (m *Model) updateRemovalDetails() {
	if m.remove == nil {
		return
	}

	width := max(1, m.width-4)
	m.remove.view.SetWidth(width)
	m.remove.view.SetHeight(m.rows)
	m.remove.view.SetContent(m.removalContent(width))
}

func (m *Model) removed(msg removedMsg) tea.Cmd {
	m.remove = nil

	m.notice = "Removed " + msg.plan.Worktree.Name
	if msg.err != nil {
		m.notice = msg.err.Error()
	} else if m.source == msg.plan.Worktree.Path || strings.HasPrefix(m.source, msg.plan.Worktree.Path+string(filepath.Separator)) {
		m.source = msg.plan.MainPath
	}

	return m.Reload("")
}
