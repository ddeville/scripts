package main

import (
	"cmp"
	"fmt"
	"strconv"
	"strings"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/tui"
)

type agentList struct {
	items  []agentItem
	index  int
	offset int
	view   viewport.Model
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
	if len(l.items) == 0 {
		l.offset = 0
		l.view.SetContent("")

		return
	}

	var (
		lines []string
		rows  []struct{ start, end int }
	)

	numberWidth := max(2, len(strconv.Itoa(len(l.items)-1)))
	counts := map[string]int{}
	statusWidth := 0

	for _, item := range l.items {
		counts[item.Cwd]++
		_, label, _ := stateStyle(item.State)
		statusWidth = max(statusWidth, ansi.StringWidth(label))
	}

	for i, item := range l.items {
		if i > 0 {
			lines = append(lines, "")
		}

		start := len(lines)

		section := i == 0 || item.Cwd != l.items[i-1].Cwd
		if section {
			lines = append(lines, locationHeading(item.Cwd, counts[item.Cwd], l.view.Width()), "")
		}

		if l.view.Height() < 4 {
			start = len(lines)
		}

		end := len(lines) + min(2, l.view.Height())
		rows = append(rows, struct{ start, end int }{start, end})
		lines = append(lines, strings.Split(item.render(l.view.Width(), numberWidth, statusWidth, i == l.index), "\n")...)
	}

	selected := rows[l.index]
	offset := min(l.offset, max(0, len(lines)-l.view.Height()))
	offset = max(selected.end-l.view.Height(), min(offset, selected.start))

	// Scroll by complete rows, keeping section headings with their first thread.
	first, headingRows := l.index, 0
	l.offset = selected.start

	for i, row := range rows {
		extra := 0
		if i > 0 && l.items[i].Cwd == l.items[i-1].Cwd && l.view.Height() >= 4 {
			extra = 2
		}

		if row.start >= offset && selected.end <= row.start+l.view.Height()-extra {
			first, headingRows = i, extra
			l.offset = row.start

			break
		}
	}

	end := l.offset
	for _, row := range rows {
		if row.end > l.offset+l.view.Height()-headingRows {
			break
		}

		if row.start >= l.offset {
			end = row.end
		}
	}

	var visible []string

	if headingRows > 0 {
		path := l.items[first].Cwd
		visible = append(visible, locationHeading(path, counts[path], l.view.Width()), "")
	}

	l.view.SetContentLines(append(visible, lines[l.offset:end]...))
}

func locationHeading(path string, count, width int) string {
	countText := fmt.Sprintf("  %d  ", count)
	location := tui.Fit(cmp.Or(tui.ShortPath(path), "Unknown location"), max(0, width-len(countText)-5))
	heading := " " + tui.Blue.Bold(true).Render(location) + tui.Muted.Render(countText)
	rule := strings.Repeat("─", max(0, width-ansi.StringWidth(heading)-1))

	return tui.Fit(heading+tui.Muted.Render(rule), width)
}

type agentItem struct {
	agent

	position int
}

func (a agentItem) render(width, numberWidth, statusWidth int, selected bool) string {
	width = max(0, width-1)
	style, label, _ := stateStyle(a.State)

	base, keyStyle, subtitleStyle := lipgloss.NewStyle(), tui.Muted, tui.Muted
	if selected {
		base = tui.Selected
		keyStyle = tui.Yellow.Background(tui.SelectedBackground)
		subtitleStyle = subtitleStyle.Background(tui.SelectedBackground)
		style = style.Background(tui.SelectedBackground)
	}

	dot := "●"
	if a.State == "idle" {
		dot = "○"
	}

	prefixWidth := numberWidth + 5

	titleWidth := max(0, width-prefixWidth)
	if titleWidth < statusWidth+18 {
		statusWidth = 0
	}

	status := ""

	if statusWidth > 0 {
		titleWidth -= statusWidth + 2
		status = base.Render("  ") + style.Render(strings.Repeat(" ", statusWidth-ansi.StringWidth(label))+label)
	}

	title := tui.SingleLine(a.Title)
	if a.ParentID != nil {
		title = "↳ " + title
	}

	marker := base.Render(" ")
	if selected {
		marker = keyStyle.Render("▎")
	}

	prefix := marker + base.Render(" ") + keyStyle.Render(fmt.Sprintf("%*d ", numberWidth, a.position)) + style.Render(dot+" ")
	name := style.Bold(selected).Render(tui.Pad(title, titleWidth))
	subtitle := marker + base.Render(strings.Repeat(" ", prefixWidth-1)) + subtitleStyle.Render(tui.Pad(tui.SingleLine(a.Preview), width-prefixWidth))
	padding := base.Render(" ")

	return fmt.Sprint(tui.Fit(prefix+name+status, width), padding, "\n", tui.Fit(subtitle, width), padding)
}
