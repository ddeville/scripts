// Package tmux locates Codex panes and switches clients to them.
package tmux

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

var titleID = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-(?:[0-9a-f]{12}|[0-9a-f]{5}\.\.\.)$`)

var errClientCount = errors.New("opening from the bar requires exactly one attached tmux client")

// SingleClient returns the only attached client, refusing an ambiguous choice.
func SingleClient(ctx context.Context) (string, error) {
	output, err := exec.CommandContext(ctx, "tmux", "list-clients", "-F", "#{client_name}").Output()
	if err != nil {
		return "", fmt.Errorf("read tmux clients: %w", err)
	}

	clients := strings.Fields(string(output))
	if len(clients) != 1 {
		return "", fmt.Errorf("%w (found %d)", errClientCount, len(clients))
	}

	return clients[0], nil
}

// PaneMatches checks all loaded IDs so truncated titles cannot resolve ambiguously.
func PaneMatches(ctx context.Context, ids []string) (map[string][]string, error) {
	output, err := exec.CommandContext(ctx, "tmux", "-u", "list-panes", "-a", "-F",
		"#{pane_id}\t#{pane_current_command}\t#{pane_title}").Output()
	if err != nil {
		return nil, fmt.Errorf("read tmux panes: %w", err)
	}

	matches := map[string][]string{}

	for line := range strings.SplitSeq(strings.TrimSpace(string(output)), "\n") {
		fields := strings.SplitN(line, "\t", 3)
		if len(fields) != 3 || fields[1] != "codex" {
			continue
		}

		title := fields[2]
		if i := strings.LastIndex(title, " | "); i >= 0 {
			title = title[i+3:]
		}

		if !titleID.MatchString(title) {
			continue
		}

		prefix := strings.TrimSuffix(title, "...")

		var candidates []string

		for _, id := range ids {
			if strings.HasPrefix(id, prefix) {
				candidates = append(candidates, id)
			}
		}

		if len(candidates) == 1 {
			id := candidates[0]
			matches[id] = append(matches[id], fields[0])
		}
	}

	return matches, nil
}

// SwitchPane selects a pane for the given client, or the current client if empty.
func SwitchPane(ctx context.Context, pane, client string) error {
	args := []string{"switch-client", "-t", pane}
	if client != "" {
		args = append(args, "-c", client)
	}

	output, err := exec.CommandContext(ctx, "tmux", args...).CombinedOutput() //nolint:gosec // Fixed executable; pane and client are separate arguments, never shell input.
	if err != nil {
		return fmt.Errorf("switch tmux pane: %w: %s", err, strings.TrimSpace(string(output)))
	}

	return nil
}
