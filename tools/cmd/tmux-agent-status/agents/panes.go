package agents

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/ddeville/scripts/tools/internal/codex"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

var titleID = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-(?:[0-9a-f]{12}|[0-9a-f]{5}\.\.\.)$`)

// ErrPaneMatch means a conversation could not be resolved to exactly one live pane.
var ErrPaneMatch = errors.New("thread must be open in exactly one tmux pane")

var errPaneChanged = errors.New("this pane no longer displays the selected thread")

// Open rechecks both the thread and the attachment. A pane ID survives moves,
// but a different process or a new conversation must never inherit a selection.
func (s *Source) Open(ctx context.Context, id string, target tmux.Pane, client string) error {
	var ids []string

	err := s.use(ctx, func(server *codex.Client) error {
		var err error

		ids, err = server.LoadedIDs(ctx)
		if err != nil {
			return fmt.Errorf("list threads: %w", err)
		}

		return nil
	})
	if err != nil {
		return fmt.Errorf("refresh loaded threads: %w", err)
	}

	if id == "" || s.Host != target.Host || !candidate(target) || displayedThread(target.Title, ids) != id {
		return errPaneChanged
	}

	if err := target.Switch(ctx, client, titleSuffix(target.Title)); err != nil {
		return fmt.Errorf("open selected pane: %w", err)
	}

	return nil
}

func matchPanes(host string, ids []string, panes []tmux.Pane) map[string][]tmux.Pane {
	matches := map[string][]tmux.Pane{}

	for _, p := range panes {
		if p.Host != host || !candidate(p) {
			continue
		}

		if id := displayedThread(p.Title, ids); id != "" {
			matches[id] = append(matches[id], p)
		}
	}

	return matches
}

func candidate(p tmux.Pane) bool {
	if p.Dead {
		return false
	}

	if p.Host == "" {
		return p.Command == "codex"
	}

	return p.Terminal != "" && p.Command == "ssh" && titleID.MatchString(titleSuffix(p.Title))
}

func titleSuffix(title string) string {
	if _, after, ok := strings.CutLast(title, " | "); ok {
		return after
	}

	return title
}

// Codex shortens the thread ID in the terminal title. Resolve against all
// loaded IDs on this host, never by directory or by the pane's initial role.
func displayedThread(title string, ids []string) string {
	title = titleSuffix(title)
	if !titleID.MatchString(title) {
		return ""
	}

	prefix := strings.TrimSuffix(title, "...")

	var match string

	for _, id := range ids {
		if len(id) != 36 || !strings.HasPrefix(id, prefix) {
			continue
		}

		if match != "" {
			return ""
		}

		match = id
	}

	return match
}
