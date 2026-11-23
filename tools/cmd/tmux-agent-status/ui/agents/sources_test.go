//nolint:testpackage // Exercise asynchronous status updates without starting a tmux server.
package agents

import (
	"testing"

	agentdata "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

func TestPaneChoicesKeepOriginAndWorktreesSeparate(t *testing.T) {
	t.Parallel()

	local := tmux.Pane{ID: "%1"}
	first := tmux.Pane{ID: "%2", Host: "dev", Terminal: "codex"}
	origin := tmux.Pane{ID: "%3", Host: "dev", Terminal: "shell"}

	m := New(origin.ID)
	m.Update(t.Context(), panesMsg{panes: []tmux.Pane{local, first, origin}})
	m.Update(t.Context(), StatusMsg{data: agentdata.Snapshot{Agents: []agentdata.Agent{{
		ID: "shared-id", Panes: []string{local.ID}, Targets: []tmux.Pane{local},
	}}}})
	m.Update(t.Context(), StatusMsg{Host: "dev", data: agentdata.Snapshot{Agents: []agentdata.Agent{{
		ID: "shared-id", Panes: []string{first.ID, origin.ID}, Targets: []tmux.Pane{first, origin},
	}}}})

	selected, ok := m.Find(m.Panel.List.SelectedID())
	if !ok || selected.Pane != origin || m.Panel.List.Len() != 3 {
		t.Fatalf("selected %v among %d choices, want the originating pane among three", selected.Pane, m.Panel.List.Len())
	}

	if m.OriginID() != "" || len(m.Local().Agents) != 1 || m.Local().Agents[0].Targets[0] != local {
		t.Fatal("remote conversation exposed as a local worktree fork source")
	}
}
