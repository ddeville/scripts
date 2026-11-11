package worktrees

import (
	"errors"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/ui/panel"
	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

func (m *Model) createView(width, rows int) string {
	form := m.create
	if form.picking {
		return form.choices.View()
	}

	var lines []string

	focusLine := 0

	for i, label := range []string{"Name", "Source", "Base"} {
		style := tui.Muted
		if i == form.focus {
			style = tui.Yellow.Bold(true)
			focusLine = len(lines)
		}

		lines = append(lines, style.Render(tui.Pad(label, 14))+form.inputs[i].View())
		if rows >= 12 {
			lines = append(lines, "")
		}
	}

	style := tui.Muted
	if form.focus == len(form.inputs) {
		style = tui.Yellow.Bold(true)
		focusLine = len(lines)
	}

	conversation := form.forkTitle
	if form.forkID == "" {
		conversation = "Choose in Codex"
	}

	if form.originPending {
		conversation = "Checking current conversation…"
	}

	if form.noTmux {
		conversation = "Not used without tmux"
	}

	hint := ""
	if !form.noTmux {
		hint = tui.Muted.Render("  [Enter to choose]")
	}

	lines = append(lines, style.Render(tui.Pad("Conversation", 14))+tui.CleanLine(conversation)+hint)
	if rows >= 12 {
		lines = append(lines, "")
	}

	checked := "[x]"
	if form.noTmux {
		checked = "[ ]"
	}

	style = lipgloss.NewStyle()
	if form.focus == len(form.inputs)+1 {
		style = tui.Yellow.Bold(true)
		focusLine = len(lines)
	}

	lines = append(lines, style.Render(checked+" Launch tmux, editor, and Codex"), "")
	if form.inputs[0].Value() != "" {
		lines = append(lines, tui.Muted.Render("Branch  ")+tui.CleanLine("damien/cw/"+form.inputs[0].Value()))
	}

	lines = append(lines, tui.Muted.Render("Root    ")+tui.ShortPath(m.root))
	start := max(0, focusLine-max(1, rows-1)+1)

	return panel.ClipLines(strings.Join(lines[start:], "\n"), rows, width)
}

func (m *Model) removalContent(width int) string {
	form := m.remove
	lines := []string{tui.Title.Render(tui.CleanLine(form.item.Repo + " / " + form.item.Name)), tui.Muted.Render(ansi.Wrap(tui.ShortPath(form.item.Path), width, "")), ""}

	branch := "Delete branch: " + form.item.Branch
	if form.keepBranch {
		branch = "Keep branch: " + form.item.Branch
	}

	if strings.HasPrefix(form.item.Branch, "detached ") {
		branch = "Detached HEAD; no branch to delete."
	}

	lines = append(lines, tui.CleanLine(branch), "")

	if !form.checking && form.err == nil {
		if len(form.plan.Sessions) == 0 {
			lines = append(lines, tui.Muted.Render("No tmux sessions to close."))
		}

		for _, session := range form.plan.Sessions {
			lines = append(lines, "Close tmux session: "+tui.CleanLine(session.Name))
		}

		lines = append(lines, "", tui.Red.Render("Press y to remove this worktree."))
	}

	if form.err != nil && !form.checking {
		message := form.err.Error()
		switch {
		case errors.Is(form.err, git.ErrNotMerged):
			message = "This branch has unmerged commits. Press k to keep the branch when removing the worktree."
		case errors.Is(form.err, worktree.ErrDirty):
			message = "This worktree has local changes. Commit or move them before removing it."
		}

		lines = append(lines, tui.Red.Render(ansi.Wrap(tui.CleanLine(message), width, "")))
	}

	if m.Busy() {
		lines = append(lines, "", "Removing worktree…")
	}

	return ansi.Wrap(strings.Join(lines, "\n"), width, "")
}

// FormView contains a modal form's content for the shared app frame.
type FormView struct{ Summary, Toolbar, Body, Footer, Help string }

// Form renders the active creation, conversation, or removal form.
func (m *Model) Form() (FormView, bool) {
	if !m.Modal() {
		return FormView{}, false
	}

	width, rows := m.width, m.rows

	var summary, toolbar, body, footer, help string
	if m.create != nil {
		summary = "Create from a committed base; local changes stay in the source."
		toolbar = "New worktree"
		title := "New worktree"
		footer = "Enter create · Esc cancel · Tab ↑/↓ fields · Space toggle"

		help = tui.Muted.Render(tui.CleanLine(m.create.message))
		if m.create.picking {
			summary = "Choose a conversation to fork into the new worktree."
			toolbar = "Running conversations, grouped by repository"
			title = "Conversation"
			footer = "j/k ↑/↓ move · Enter choose · Esc back"
			help = tui.Muted.Render("Choose in Codex also lets you browse saved conversations.")
		}

		body = panel.Render(title, m.createView(width-4, rows), width, rows, true)
	} else if m.remove != nil {
		summary = "Review the checkout, branch, and tmux sessions below."
		toolbar = "Remove worktree"

		footer = "y remove · Esc cancel · k keep branch · ↑/↓ scroll"
		if m.remove.keepBranch {
			footer = "y remove · Esc cancel · k delete branch · ↑/↓ scroll"
		}

		help = ""
		if m.remove.checking {
			help = tui.Muted.Render("Checking Git and tmux…")
		}

		if m.remove.err != nil || m.remove.checking {
			footer = "k keep/delete branch · ↑/↓ scroll · Esc cancel"
		}

		body = panel.Render("Remove worktree", m.remove.view.View(), width, rows, true)
	}

	return FormView{Summary: summary, Toolbar: toolbar, Body: body, Footer: footer, Help: help}, true
}
