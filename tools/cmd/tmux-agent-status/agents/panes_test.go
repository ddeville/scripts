//nolint:testpackage // Test matching without invoking the user's tmux server.
package agents

import (
	"reflect"
	"testing"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

func TestMatchPanesDoesNotGuess(t *testing.T) {
	t.Parallel()

	first := "12345678-1234-1234-1234-123450000000"
	collision := "12345678-1234-1234-1234-123450000001"
	unique := "87654321-1234-1234-1234-123450000000"
	ids := []string{first, collision, unique}
	panes := []tmux.Pane{
		{ID: "%1", Command: "codex", Title: "project | " + first},
		{ID: "%2", Command: "codex", Title: first},
		{ID: "%3", Command: "codex", Title: "12345678-1234-1234-1234-12345..."},
		{ID: "%4", Command: "codex", Title: "87654321-1234-1234-1234-12345..."},
		{ID: "%5", Command: "fish", Title: unique},
	}

	want := map[string][]string{first: {"%1", "%2"}, unique: {"%4"}}
	if got := matchPanes(ids, panes); !reflect.DeepEqual(got, want) {
		t.Fatalf("pane matches = %v, want %v; ambiguous titles must be ignored and duplicate panes preserved", got, want)
	}
}
