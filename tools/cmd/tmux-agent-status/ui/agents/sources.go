package agents

import (
	"context"
	"errors"
	"slices"
	"time"

	tea "charm.land/bubbletea/v2"

	agentdata "github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

// Each destination refreshes independently so an unreachable host cannot
// stall the local dashboard or other SSH destinations.
type destination struct {
	source agentdata.Source
	data   agentdata.Snapshot
	busy   bool
}

type panesMsg struct {
	panes []tmux.Pane
	err   error
}

// StatusMsg contains a new snapshot for one app server.
type StatusMsg struct {
	Host string
	data agentdata.Snapshot
}

var errDisconnected = errors.New("SSH disconnected")

func scan(ctx context.Context) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(ctx, time.Second)
		defer cancel()

		panes, err := tmux.ListPanes(ctx)

		return panesMsg{panes, err}
	}
}

func (m *Model) fetch(ctx context.Context, msg panesMsg) tea.Cmd {
	cmds := []tea.Cmd{tea.Tick(time.Second, func(time.Time) tea.Msg { return tickMsg{} })}

	m.scanErr = msg.err
	if msg.err != nil {
		return tea.Batch(cmds...)
	}

	groups := map[string][]tmux.Pane{"": {}}

	for _, p := range msg.panes {
		if p.Host != "" && p.Terminal == "" {
			continue
		}

		groups[p.Host] = append(groups[p.Host], p)
		if p.ID == m.initialPane {
			m.initialHost = p.Host
		}
	}

	for host, dest := range m.hosts {
		if _, ok := groups[host]; !ok && !dest.busy {
			delete(m.hosts, host)
			cmds = append(cmds, m.updateAgents(ctx))

			dest.source.Close()
		}
	}

	for host, panes := range groups {
		dest := m.hosts[host]
		if dest == nil {
			dest = &destination{source: agentdata.Source{Host: host}}
			m.hosts[host] = dest
		}

		if dest.busy {
			continue
		}

		dest.busy = true

		cmds = append(cmds, func() tea.Msg {
			ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
			defer cancel()

			if host != "" && !slices.ContainsFunc(panes, func(p tmux.Pane) bool { return !p.Dead }) {
				dest.source.Close()
				return StatusMsg{host, agentdata.Snapshot{At: time.Now(), Err: errDisconnected}}
			}

			return StatusMsg{host, dest.source.Collect(ctx, panes)}
		})
	}

	return tea.Batch(cmds...)
}

// Close releases the popup's app-server connections.
func (m *Model) Close() {
	for _, dest := range m.hosts {
		dest.source.Close()
	}
}

// Local is the only source of thread IDs and paths for worktree operations.
func (m *Model) Local() agentdata.Snapshot { return m.hosts[""].data }

// Choice identifies a specific local view of a conversation.
type Choice struct {
	Agent  agentdata.Agent
	Pane   tmux.Pane
	Source *agentdata.Source
}

func (c Choice) key() string {
	return c.Pane.ID + "/" + c.Pane.Terminal + "/" + c.Pane.Host + "/" + c.Agent.ID
}

// Find resolves an agent list row without guessing between duplicate views.
func (m *Model) Find(key string) (Choice, bool) {
	c, ok := m.choices[key]
	return c, ok
}
