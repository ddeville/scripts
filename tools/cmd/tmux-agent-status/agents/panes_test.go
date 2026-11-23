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
		{ID: "%6", Command: "codex", Title: unique[:8]},
	}

	want := map[string][]tmux.Pane{first: {panes[0], panes[1]}, unique: {panes[3]}}
	if got := matchPanes("", ids, panes); !reflect.DeepEqual(got, want) {
		t.Fatalf("pane matches = %v, want %v; ambiguous titles must be ignored and duplicate panes preserved", got, want)
	}
}

func TestRemoteMatchesStayOnOneHost(t *testing.T) {
	t.Parallel()

	const (
		id    = "12345678-1234-1234-1234-123450000000"
		title = "same project | 12345678-1234-1234-1234-12345..."
	)

	panes := []tmux.Pane{
		{ID: "%1", Command: "codex", Title: title},
		{ID: "%2", Host: "other", Terminal: "shell", Command: "ssh", Title: title},
		{ID: "%3", Host: "dev", Terminal: "shell", Command: "ssh", Title: title},
		{ID: "%4", Host: "dev", Terminal: "codex", Command: "ssh", Title: title, Dead: true},
		{ID: "%5", Host: "dev", Terminal: "shell", Command: "fish", Title: title},
		{ID: "%6", Host: "dev", Command: "ssh", Title: title},
	}

	for host, target := range map[string]tmux.Pane{"": panes[0], "other": panes[1], "dev": panes[2]} {
		got := matchPanes(host, []string{id}, panes)
		if !reflect.DeepEqual(got[id], []tmux.Pane{target}) {
			t.Errorf("matches on %q = %v, want only %s", host, got, target.ID)
		}
	}
}
