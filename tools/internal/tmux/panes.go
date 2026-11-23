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

// Pane describes a pane's session, foreground command, and terminal title.
type Pane struct {
	ID, PID        string
	Host, Terminal string
	Dead           bool
	SessionNumber  int
	Command        string
	Title          string
}

// ListPanes lists panes across all sessions in the current server.
func ListPanes(ctx context.Context) ([]Pane, error) {
	// Titles come from programs, including remote ones. Keep control characters
	// out of the record delimiters before tmux writes the listing.
	const format = "#{pane_id}\t#{session_id}\t#{pane_pid}\t#{pane_dead}\t#{@tm_host}\t#{@tm_terminal}\t#{pane_current_command}\t#{s/[\x01-\x1f]/_/:pane_title}"

	output, err := run(ctx, "-u", "list-panes", "-a", "-F", format)
	if err != nil {
		return nil, fmt.Errorf("read tmux panes: %w", err)
	}

	var panes []Pane

	seen := make(map[string]int)

	for line := range strings.Lines(output) {
		fields := strings.Split(strings.TrimSuffix(line, "\n"), "\t")
		if len(fields) != 8 {
			continue
		}

		sessionNumber, err := strconv.Atoi(strings.TrimPrefix(fields[1], "$"))
		if err != nil {
			continue
		}

		if i, ok := seen[fields[0]]; ok {
			panes[i].SessionNumber = min(panes[i].SessionNumber, sessionNumber)
			continue
		}

		seen[fields[0]] = len(panes)
		panes = append(panes, Pane{
			ID: fields[0], SessionNumber: sessionNumber, PID: fields[2], Dead: fields[3] == "1",
			Host: fields[4], Terminal: fields[5], Command: fields[6], Title: fields[7],
		})
	}

	return panes, nil
}

// Switch checks the process and final " | " title field in the same command
// queue that switches clients. Earlier fields can change with each TUI redraw.
func (p Pane) Switch(ctx context.Context, client, titleField string) error {
	if client == "" {
		var err error

		client, err = SingleClient(ctx)
		if err != nil {
			return err
		}
	}

	const view = "#{pane_id}\t#{pane_pid}\t#{pane_dead}\t#{@tm_host}\t#{@tm_terminal}\t#{pane_current_command}\t#{s/^.* [|] //:pane_title}"

	expected := strings.Join([]string{p.ID, p.PID, "0", p.Host, p.Terminal, p.Command, titleField}, "\t")
	escape := strings.NewReplacer("#", "#{a:35}", ",", "#{a:44}", "}", "#{a:125}")
	same := "#{==:" + view + "," + escape.Replace(expected) + "}"

	command := commandLine("switch-client", "-t", p.ID, "-c", client)

	out, err := run(ctx, "if-shell", "-F", "-t", p.ID, same, command, "display-message -p changed")
	if err != nil {
		return err
	}

	if out != "" {
		return errPaneChanged
	}

	return nil
}

var errPaneChanged = errors.New("selected pane changed")
