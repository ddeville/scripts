package main

import (
	"errors"
	"fmt"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tui"
)

func (m *model) columns() (left, right int) {
	width := max(1, m.width-2)
	if width < 86 {
		return width, 0
	}

	left = (width - 3) / 2

	return left, width - left - 3
}

func (m *model) renderList() {
	var lines []string

	counts := map[string]int{}
	for _, item := range m.items {
		counts[item.Repo]++
	}

	start, end := 0, 0

	width := m.view.Width()
	for position, item := range m.items {
		rowStart := len(lines)

		if position == 0 || item.Repo != m.items[position-1].Repo {
			lines = append(lines, "", tui.SectionHeading(item.Repo, counts[item.Repo], width))
		}

		if position == m.index {
			start, end = rowStart, len(lines)+min(2, m.view.Height())
		}

		state, style := statusStyle(item.Status)
		base := lipgloss.NewStyle()
		marker := " "
		branchStyle := tui.Muted

		if position == m.index {
			marker, base = "▎", tui.Selected
			style = style.Background(tui.SelectedBackground)
			branchStyle = branchStyle.Background(tui.SelectedBackground)
		}

		prefix := fmt.Sprintf("%s %d ", marker, position)
		nameWidth := max(0, width-ansi.StringWidth(prefix)-ansi.StringWidth(state)-2)
		first := base.Render(prefix+tui.Pad(tui.CleanLine(item.Name), nameWidth)+"  ") + style.Render(state)
		second := branchStyle.Render(tui.Pad("    "+tui.CleanLine(item.Branch), width))
		lines = append(lines, tui.Fit(first, width), second)
	}

	if len(lines) == 0 {
		lines = []string{"", "No managed worktrees yet.", "", "Press n to create your first worktree.", "", tui.ShortPath(m.root)}
	}

	offset := m.view.YOffset()
	m.view.SetContentLines(lines)
	m.view.SetYOffset(max(end-m.view.Height(), min(offset, start)))
}

func statusStyle(status string) (string, lipgloss.Style) {
	switch status {
	case "clean":
		return "clean", tui.Green
	case "dirty":
		return "dirty", tui.Yellow
	case "unknown":
		return "error", tui.Red
	default:
		return "…", tui.Muted
	}
}

func (m *model) details(width, height int) string {
	item, ok := m.selected()
	if !ok {
		return tui.Muted.Render(ansi.Wrap("Create a worktree with n.", width, ""))
	}

	state, style := statusStyle(item.Status)
	lines := []string{
		lipgloss.NewStyle().Bold(true).Render(tui.Fit(tui.CleanLine(item.Name), width)),
		style.Render(state) + tui.Muted.Render(" working tree"),
		tui.Muted.Render("Branch  ") + tui.Fit(tui.CleanLine(item.Branch), max(1, width-8)), "",
		tui.Muted.Render("TMUX SESSION"),
	}

	session := "Enter creates repo / editor / Codex"
	if !m.sessionsReady {
		session = "Checking sessions…"
	} else if item.Session.ID != "" {
		session = tui.CleanLine(item.Session.Name)
	}

	lines = append(lines, tui.Fit(session, width), "", tui.Muted.Render("CHANGES"))

	changes := m.changes[item.Path]
	switch {
	case item.StatusError != "":
		lines = append(lines, tui.Red.Render(ansi.Wrap(tui.CleanLine(item.StatusError), width, "")))
	case changes == "":
		text := "No local changes"
		if item.Status != "clean" {
			text = "Reading Git status…"
		}

		lines = append(lines, tui.Muted.Render(text))
	default:
		for line := range strings.SplitSeq(changes, "\n") {
			lines = append(lines, tui.Fit(tui.CleanLine(line), width))
		}
	}

	return clippedLines(strings.Join(lines, "\n"), height, width)
}

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

func (m *model) browseView(width int) string {
	_, right := m.columns()

	body := m.view.View()
	if right > 0 {
		separator := tui.Muted.Render(strings.TrimSuffix(strings.Repeat(" │ \n", m.view.Height()), "\n"))
		body = lipgloss.JoinHorizontal(lipgloss.Top, body, separator, m.details(right, m.view.Height()))
	}

	return clippedLines(body, m.view.Height(), width)
}

func (m *model) View() tea.View {
	width := max(1, m.width-2)
	header := lipgloss.NewStyle().Bold(true).Render("Worktrees")
	header += tui.Muted.Render(fmt.Sprintf("  %d", len(m.items)))
	toolbar := tui.Yellow.Render("Enter") + " open   " + tui.Yellow.Render("n") + " new   " + tui.Yellow.Render("d") + " remove   " + tui.Yellow.Render("r") + " refresh"
	body := m.browseView(width)

	footer := "j/k ↑/↓ move · 0–9 open · q close"

	notice := m.notice
	if notice == "" {
		if item, ok := m.selected(); ok {
			notice = tui.ShortPath(item.Path)
		}
	}

	if m.create != nil {
		header, toolbar = lipgloss.NewStyle().Bold(true).Render("New worktree"), "Create from a committed base; local changes stay in the source."
		body = m.createView(width)
		footer, notice = "Enter create · Esc cancel · Tab ↑/↓ fields · Space toggle", m.create.message
	} else if m.remove != nil {
		header, toolbar = tui.Red.Bold(true).Render("Remove worktree"), "Review the checkout, branch, and tmux sessions below."
		body = m.removeView(width)

		footer, notice = "y remove · Esc cancel · k keep branch · ↑/↓ scroll", ""
		if m.remove.keepBranch {
			footer = "y remove · Esc cancel · k delete branch · ↑/↓ scroll"
		}

		if m.remove.err != nil || m.remove.checking {
			footer = "k keep/delete branch · ↑/↓ scroll · Esc cancel"
		}

		if m.remove.checking {
			notice = "Checking Git and tmux…"
		}
	}

	if m.busy {
		footer = "Working…"
	}

	content := strings.Join([]string{
		tui.Fit(header, width), tui.Fit(toolbar, width), tui.Muted.Render(strings.Repeat("─", width)),
		lipgloss.NewStyle().Height(m.view.Height()).Render(clippedLines(body, m.view.Height(), width)),
		tui.Fit(tui.Yellow.Render(tui.CleanLine(notice)), width), tui.Fit(tui.Muted.Render(footer), width),
	}, "\n")
	view := tea.NewView(tui.Frame.Render(content))
	view.AltScreen = true

	return view
}

func (m *model) createView(width int) string {
	form := m.create

	var lines []string

	focusLine := 0

	for i, label := range []string{"Name", "Source", "Base", "Fork thread"} {
		style := tui.Muted
		if i == form.focus {
			style = tui.Yellow.Bold(true)
			focusLine = len(lines)
		}

		lines = append(lines, style.Render(tui.Pad(label, 13))+form.inputs[i].View())
		if m.view.Height() >= 12 {
			lines = append(lines, "")
		}
	}

	checked := "[x]"
	if form.noTmux {
		checked = "[ ]"
	}

	style := lipgloss.NewStyle()
	if form.focus == len(form.inputs) {
		style = tui.Yellow.Bold(true)
		focusLine = len(lines)
	}

	lines = append(lines, style.Render(checked+" Launch tmux, editor, and Codex"), "")
	if form.inputs[0].Value() != "" {
		lines = append(lines, tui.Muted.Render("Branch  ")+tui.CleanLine("damien/cw/"+form.inputs[0].Value()))
	}

	lines = append(lines, tui.Muted.Render("Root    ")+tui.ShortPath(m.root))
	if !form.noTmux {
		lines = append(lines, tui.Muted.Render("Leave Fork thread empty to choose a conversation in Codex."))
	}

	start := max(0, focusLine-max(1, m.view.Height()-1)+1)

	return clippedLines(strings.Join(lines[start:], "\n"), m.view.Height(), width)
}

func (m *model) removeView(width int) string {
	form := m.remove
	lines := []string{
		lipgloss.NewStyle().Bold(true).Render(tui.CleanLine(form.item.Repo + " / " + form.item.Name)),
		ansi.Wrap(tui.ShortPath(form.item.Path), width, ""), "",
	}

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
		case errors.Is(form.err, errDirty):
			message = "This worktree has local changes. Commit or move them before removing it."
		}

		lines = append(lines, tui.Red.Render(ansi.Wrap(tui.CleanLine(message), width, "")))
	}

	if m.busy {
		lines = append(lines, "", "Removing worktree…")
	}

	content := strings.Split(strings.Join(lines, "\n"), "\n")
	form.offset = min(form.offset, max(0, len(content)-m.view.Height()))

	return clippedLines(strings.Join(content[form.offset:], "\n"), m.view.Height(), width)
}
