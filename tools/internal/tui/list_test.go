package tui_test

import (
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func TestListResizesWithoutHidingRowsInBlankSpace(t *testing.T) {
	t.Parallel()

	list := tui.NewList()
	list.SetItems([]tui.ListItem{
		{ID: "0", Group: "Project", Title: "First", Subtitle: "Description A"},
		{ID: "1", Group: "Project", Title: "Second", Subtitle: "Description B"},
		{ID: "2", Group: "Project", Title: "Third", Subtitle: "Description C"},
		{ID: "3", Group: "Project", Title: "Fourth", Subtitle: "Description D"},
	}, "0")

	view := func(rows int) string {
		t.Helper()

		text := ansi.Strip(list.View())
		if got := strings.Count(text, "\n") + 1; got != rows {
			t.Fatalf("viewport has %d rows, want %d:\n%s", got, rows, text)
		}

		return text
	}

	list.SetSize(80, 8)

	compact := view(8)
	if !strings.Contains(compact, "Fourth") || strings.Contains(compact, "Description D") {
		t.Fatalf("bottom row should show the next entry's title without overflowing the viewport:\n%s", compact)
	}

	for line := range strings.SplitSeq(compact, "\n") {
		if strings.TrimSpace(line) == "" {
			t.Fatalf("compact list left a blank row while content was hidden:\n%s", compact)
		}
	}

	list.SelectID("3")

	selected := view(8)
	if !strings.Contains(selected, "Fourth") || !strings.Contains(selected, "Description D") || !strings.Contains(selected, "Project") {
		t.Fatalf("selected row or its group heading was clipped:\n%s", selected)
	}

	list.SetSize(80, 13)

	roomy := view(13)
	if list.SelectedID() != "3" || !strings.Contains(roomy, "First") || !strings.Contains(roomy, "Fourth") || !strings.Contains(roomy, "Description D") {
		t.Fatalf("enlarging lost selection or hid content that fits:\n%s", roomy)
	}

	if !strings.Contains(strings.ReplaceAll(roomy, " ", ""), "DescriptionA\n\n") {
		t.Fatalf("spacing was not restored when the list fitted:\n%s", roomy)
	}
}
