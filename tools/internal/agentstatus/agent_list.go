package agentstatus

import (
	"cmp"
	"fmt"
	"strings"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type agentList struct {
	items []agentItem
	index int
	view  viewport.Model
}

func newAgentList() agentList { return agentList{view: viewport.New()} }

func (l *agentList) setSize(width, height int) {
	l.view.SetWidth(width)
	l.view.SetHeight(height)
	l.render()
}

func (l *agentList) selectIndex(index int) {
	l.index = max(0, min(index, len(l.items)-1))
	l.render()
}

func (l *agentList) move(msg tea.KeyPressMsg) {
	if len(l.items) == 0 {
		return
	}

	switch {
	case key.Matches(msg, keys.up):
		l.selectIndex((l.index + len(l.items) - 1) % len(l.items))
	case key.Matches(msg, keys.down):
		l.selectIndex((l.index + 1) % len(l.items))
	case key.Matches(msg, keys.first):
		l.selectIndex(0)
	case key.Matches(msg, keys.last):
		l.selectIndex(len(l.items) - 1)
	}
}

func (l *agentList) render() {
	var lines []string

	top, bottom := 0, 0

	for i, item := range l.items {
		section := i == 0 || item.Cwd != l.items[i-1].Cwd
		if section {
			if i > 0 {
				lines = append(lines, "")
			}

			location := cmp.Or(shortPath(item.Cwd), "Unknown location")
			lines = append(lines, blue.Bold(true).Render(fit(" "+location, l.view.Width())))
		}

		if i == l.index {
			top = len(lines)

			bottom = top + min(2, l.view.Height())
			if section && l.view.Height() >= 3 {
				top--
			}
		}

		lines = append(lines, strings.Split(item.render(l.view.Width(), i == l.index), "\n")...)
	}

	l.view.SetContentLines(lines)

	if bottom > l.view.YOffset()+l.view.Height() {
		l.view.SetYOffset(bottom - l.view.Height())
	}

	if top < l.view.YOffset() {
		l.view.SetYOffset(top)
	}
}

type agentItem struct {
	agent

	position int
}

func (a agentItem) render(width int, selected bool) string {
	width = max(0, width-1)
	style, label, _ := stateStyle(a.State)

	base, keyStyle, pathStyle := lipgloss.NewStyle(), yellow, muted
	if selected {
		base = base.Background(selectedBackground)
		keyStyle = keyStyle.Background(selectedBackground)
		pathStyle = pathStyle.Background(selectedBackground)
		style = style.Background(selectedBackground)
	}

	dot := "●"
	if a.State == "idle" {
		dot = "○"
	}

	number := " "
	if a.position < 10 {
		number = string("0123456789"[a.position])
	}

	titleWidth := max(1, width-21)

	title := singleLine(a.Title)
	if a.ParentID != nil {
		title = "↳ " + title
	}

	prefix := keyStyle.Render(" "+number+" ") + style.Render(dot+" ")
	name := style.Render(pad(title, titleWidth) + "  ")
	status := style.Render(pad(label, 14))
	metadata := a.Type.label() + " · " + shortPath(a.Cwd)
	project := base.Render("     ") + pathStyle.Render(pad(metadata, width-5))
	padding := base.Render(" ")

	return fmt.Sprint(fit(prefix+name+status, width), padding, "\n", fit(project, width), padding)
}
