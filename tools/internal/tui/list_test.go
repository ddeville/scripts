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
		{ID: "0", Group: "Project", Title: "First", Subtitle: "First details"},
		{ID: "1", Group: "Project", Title: "Second", Subtitle: "Second details"},
		{ID: "2", Group: "Project", Title: "Third", Subtitle: "Third details"},
		{ID: "3", Group: "Project", Title: "Fourth", Subtitle: "Fourth details"},
	}, "0")
	list.SetSize(80, 8)

	compact := ansi.Strip(list.View())
	if !strings.Contains(compact, "Fourth") {
		t.Fatalf("available bottom row did not show the next entry:\n%s", compact)
	}

	for line := range strings.SplitSeq(compact, "\n") {
		if strings.TrimSpace(line) == "" {
			t.Fatalf("compact list left a blank row while content was hidden:\n%s", compact)
		}
	}

	list.SelectID("3")

	if view := ansi.Strip(list.View()); !strings.Contains(view, "Fourth details") || !strings.Contains(view, "Project") {
		t.Fatalf("selected row or its group heading was clipped:\n%s", view)
	}

	list.SetSize(80, 13)

	roomy := ansi.Strip(list.View())
	if list.SelectedID() != "3" || !strings.Contains(roomy, "First") || !strings.Contains(roomy, "Fourth details") {
		t.Fatalf("enlarging lost selection or hid content that fits:\n%s", roomy)
	}

	if !strings.Contains(strings.ReplaceAll(roomy, " ", ""), "Firstdetails\n\n") {
		t.Fatalf("spacing was not restored when the list fitted:\n%s", roomy)
	}
}
