package tui

import (
	"fmt"
	"slices"
	"strconv"
	"strings"

	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

// ListItem is a two-line row in a grouped navigation list.
type ListItem struct {
	ID, Group, Title, Subtitle, Status, Indicator string
	Style                                         lipgloss.Style
}

// List keeps selection, group headings, and complete rows visible while scrolling.
type List struct {
	Items  []ListItem
	Index  int
	offset int
	view   viewport.Model
}

// NewList creates an empty grouped list.
func NewList() List { return List{view: viewport.New()} }

// SetSize resizes the visible rows without changing selection.
func (l *List) SetSize(width, height int) {
	l.view.SetWidth(max(1, width))
	l.view.SetHeight(max(1, height))
	l.render()
}

// Select clamps the index and scrolls to the selected row.
func (l *List) Select(index int) {
	l.Index = max(0, min(index, len(l.Items)-1))
	l.render()
}

// SelectID preserves selection across a refreshed or reordered item list.
func (l *List) SelectID(id string) {
	l.Select(slices.IndexFunc(l.Items, func(item ListItem) bool { return item.ID == id }))
}

// SelectedID returns an empty string when the list has no rows.
func (l *List) SelectedID() string {
	if len(l.Items) == 0 {
		return ""
	}

	return l.Items[l.Index].ID
}

// Move handles the shared arrow, Vim, and page navigation keys.
func (l *List) Move(msg tea.KeyPressMsg) {
	if len(l.Items) == 0 {
		return
	}

	switch msg.String() {
	case "k", "up", "ctrl+p":
		l.Select((l.Index + len(l.Items) - 1) % len(l.Items))
	case "j", "down", "ctrl+n":
		l.Select((l.Index + 1) % len(l.Items))
	case "g", "home":
		l.Select(0)
	case "G", "end":
		l.Select(len(l.Items) - 1)
	case "pgup":
		l.Select(l.Index - max(1, l.view.Height()/3))
	case "pgdown":
		l.Select(l.Index + max(1, l.view.Height()/3))
	}
}

// View renders the visible groups and rows.
func (l *List) View() string { return l.view.View() }

// Width is the available content width in terminal cells.
func (l *List) Width() int { return l.view.Width() }

// Height is the available content height in terminal rows.
func (l *List) Height() int { return l.view.Height() }

func (l *List) render() {
	if len(l.Items) == 0 {
		l.offset = 0
		l.view.SetContent("")

		return
	}

	var (
		lines []string
		rows  []struct{ start, end int }
	)

	numberWidth := max(2, len(strconv.Itoa(len(l.Items)-1)))
	counts := map[string]int{}
	statusWidth := 0

	for _, item := range l.Items {
		counts[item.Group]++
		statusWidth = max(statusWidth, ansi.StringWidth(item.Status))
	}

	for i, item := range l.Items {
		if i > 0 {
			lines = append(lines, "")
		}

		start := len(lines)
		if i == 0 || item.Group != l.Items[i-1].Group {
			lines = append(lines, SectionHeading(item.Group, counts[item.Group], l.view.Width()), "")
		}

		if l.view.Height() < 4 {
			start = len(lines)
		}

		end := len(lines) + min(2, l.view.Height())
		rows = append(rows, struct{ start, end int }{start, end})
		lines = append(lines, strings.Split(item.render(l.view.Width(), numberWidth, statusWidth, i, i == l.Index), "\n")...)
	}

	selected := rows[l.Index]
	offset := min(l.offset, max(0, len(lines)-l.view.Height()))
	offset = max(selected.end-l.view.Height(), min(offset, selected.start))
	first, headingRows := l.Index, 0
	l.offset = selected.start

	for i, row := range rows {
		extra := 0
		if i > 0 && l.Items[i].Group == l.Items[i-1].Group && l.view.Height() >= 4 {
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
		group := l.Items[first].Group
		visible = append(visible, SectionHeading(group, counts[group], l.view.Width()), "")
	}

	l.view.SetContentLines(append(visible, lines[l.offset:end]...))
}

func (a ListItem) render(width, numberWidth, statusWidth, position int, selected bool) string {
	width = max(0, width-1)
	style := a.Style

	base, keyStyle, subtitleStyle := lipgloss.NewStyle(), Muted, Muted
	if selected {
		base = Selected
		keyStyle = Yellow.Background(SelectedBackground)
		subtitleStyle = subtitleStyle.Background(SelectedBackground)
		style = style.Background(SelectedBackground)
	}

	indicator := a.Indicator
	if indicator != "" {
		indicator += " "
	}

	prefixWidth := numberWidth + 3 + ansi.StringWidth(indicator)

	titleWidth := max(0, width-prefixWidth)
	if titleWidth < statusWidth+18 {
		statusWidth = 0
	}

	status := ""

	if statusWidth > 0 {
		titleWidth -= statusWidth + 2
		status = base.Render("  ") + style.Render(strings.Repeat(" ", statusWidth-ansi.StringWidth(a.Status))+a.Status)
	}

	marker := base.Render(" ")
	if selected {
		marker = keyStyle.Render("▎")
	}

	prefix := marker + base.Render(" ") + keyStyle.Render(fmt.Sprintf("%*d ", numberWidth, position)) + style.Render(indicator)
	name := style.Bold(selected).Render(Pad(SingleLine(a.Title), titleWidth))
	subtitle := marker + base.Render(strings.Repeat(" ", prefixWidth-1)) + subtitleStyle.Render(Pad(SingleLine(a.Subtitle), width-prefixWidth))
	padding := base.Render(" ")

	return fmt.Sprint(Fit(prefix+name+status, width), padding, "\n", Fit(subtitle, width), padding)
}
