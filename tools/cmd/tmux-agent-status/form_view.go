package main

import (
	"errors"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

func clippedLines(text string, height, width int) string {
	lines := strings.Split(text, "\n")
	if len(lines) > height {
		lines = lines[:height]
		if height > 1 {
			lines[height-1] = tui.Muted.Render("…")
		}
	}

	for i := range lines {
		lines[i] = tui.Fit(lines[i], width)
	}

	return strings.Join(lines, "\n")
}

func (m *model) createView(width, rows int) string {
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

	return clippedLines(strings.Join(lines[start:], "\n"), rows, width)
}

func (m *model) removeView(width, rows int) string {
	form := m.remove
	lines := []string{tui.Yellow.Bold(true).Render(tui.CleanLine(form.item.Repo + " / " + form.item.Name)), tui.Blue.Render(ansi.Wrap(tui.ShortPath(form.item.Path), width, "")), ""}

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

	if m.busy {
		lines = append(lines, "", "Removing worktree…")
	}

	content := strings.Split(strings.Join(lines, "\n"), "\n")
	form.offset = min(form.offset, max(0, len(content)-rows))

	return clippedLines(strings.Join(content[form.offset:], "\n"), rows, width)
}
