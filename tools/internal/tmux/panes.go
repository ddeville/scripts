// Package tmux manages sessions, windows, panes, and clients.
package tmux

import (
	"context"
	"errors"
	"fmt"
	"strings"
)

var errClientCount = errors.New("expected exactly one attached tmux client")

// SingleClient returns the only attached client, refusing an ambiguous choice.
func SingleClient(ctx context.Context) (string, error) {
	output, err := run(ctx, "list-clients", "-F", "#{client_name}")
	if err != nil {
		return "", fmt.Errorf("read tmux clients: %w", err)
	}

	clients := strings.Fields(output)
	if len(clients) != 1 {
		return "", fmt.Errorf("%w (found %d)", errClientCount, len(clients))
	}

	return clients[0], nil
}

// Pane describes a pane's foreground command and terminal title.
type Pane struct {
	ID      string
	Command string
	Title   string
}

// ListPanes lists panes across all sessions in the current server.
func ListPanes(ctx context.Context) ([]Pane, error) {
	output, err := run(ctx, "-u", "list-panes", "-a", "-F", "#{pane_id}\t#{pane_current_command}\t#{pane_title}")
	if err != nil {
		return nil, fmt.Errorf("read tmux panes: %w", err)
	}

	var panes []Pane

	for line := range strings.SplitSeq(strings.TrimSpace(output), "\n") {
		fields := strings.SplitN(line, "\t", 3)
		if len(fields) != 3 {
			continue
		}

		panes = append(panes, Pane{ID: fields[0], Command: fields[1], Title: fields[2]})
	}

	return panes, nil
}

// SwitchPane selects a pane for the given client, or the current client if empty.
func SwitchPane(ctx context.Context, pane, client string) error {
	return switchClient(ctx, pane, client)
}
