// Package tmux manages sessions, windows, panes, and clients.
package tmux

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

var errClientCount = errors.New("expected exactly one attached tmux client")

// SingleClient returns the only attached client, refusing an ambiguous choice.
func SingleClient(ctx context.Context) (string, error) {
	output, err := Run(ctx, "list-clients", "-F", "#{client_name}")
	if err != nil {
		return "", fmt.Errorf("read tmux clients: %w", err)
	}

	clients := strings.Fields(output)
	if len(clients) != 1 {
		return "", fmt.Errorf("%w (found %d)", errClientCount, len(clients))
	}

	return clients[0], nil
}

// Pane describes a pane's session, foreground command, and terminal title.
type Pane struct {
	ID            string
	SessionNumber int
	Command       string
	Title         string
}

// ListPanes lists panes across all sessions in the current server.
func ListPanes(ctx context.Context) ([]Pane, error) {
	output, err := Run(ctx, "-u", "list-panes", "-a", "-F", "#{pane_id}\t#{session_id}\t#{pane_current_command}\t#{pane_title}")
	if err != nil {
		return nil, fmt.Errorf("read tmux panes: %w", err)
	}

	var panes []Pane

	for line := range strings.SplitSeq(strings.TrimSpace(output), "\n") {
		fields := strings.SplitN(line, "\t", 4)
		if len(fields) != 4 {
			continue
		}

		sessionNumber, err := strconv.Atoi(strings.TrimPrefix(fields[1], "$"))
		if err != nil {
			continue
		}

		panes = append(panes, Pane{ID: fields[0], SessionNumber: sessionNumber, Command: fields[2], Title: fields[3]})
	}

	return panes, nil
}

// SwitchPane selects a pane for the given client, or the current client if empty.
func SwitchPane(ctx context.Context, pane, client string) error {
	return switchClient(ctx, pane, client)
}
