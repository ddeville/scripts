package agents

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var titleID = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-(?:[0-9a-f]{12}|[0-9a-f]{5}\.\.\.)$`)

// ErrPaneMatch means a conversation could not be resolved to exactly one live pane.
var ErrPaneMatch = errors.New("thread must be open in exactly one tmux pane")

// MatchPanes checks all loaded IDs so truncated titles cannot resolve ambiguously.
func MatchPanes(ctx context.Context, ids []string) (map[string][]string, error) {
	panes, err := tmux.ListPanes(ctx)
	if err != nil {
		return nil, fmt.Errorf("match agent panes: %w", err)
	}

	matches := map[string][]string{}

	for _, pane := range panes {
		if pane.Command != "codex" {
			continue
		}

		title := pane.Title
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
			matches[id] = append(matches[id], pane.ID)
		}
	}

	return matches, nil
}
