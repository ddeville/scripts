package worktree

import (
	"context"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/ddeville/scripts/tools/internal/session"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

type sessionOptions struct {
	Fork       string
	ForkPicker bool
	SourceDir  string
}

func sessionName(item Info) string {
	return strings.NewReplacer(".", "_", ":", "_").Replace(item.Repo + "-" + item.Name)
}

// MatchSession matches canonical checkout paths, preferring the usual session name.
func MatchSession(item Info, sessions []tmux.Session) tmux.Session {
	var match tmux.Session

	for _, candidate := range sessions {
		if candidate.Path == item.Path {
			if match.ID == "" || candidate.Name == sessionName(item) {
				match = candidate
			}
		}
	}

	return match
}

// Open reuses a matching session or creates the usual repo/editor/Codex windows.
func Open(ctx context.Context, item Info) (string, error) {
	return ensureSession(ctx, item, sessionOptions{})
}

func ensureSession(ctx context.Context, item Info, options sessionOptions) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	if _, err := readBranch(item.Path); err != nil {
		return "", fmt.Errorf("worktree is no longer available: %w", err)
	}

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return "", fmt.Errorf("list sessions: %w", err)
	}

	if existing := MatchSession(item, sessions); existing.ID != "" {
		return existing.ID, nil
	}

	name := sessionName(item)
	for suffix := 2; slices.ContainsFunc(sessions, func(s tmux.Session) bool { return s.Name == name }); suffix++ {
		name = fmt.Sprintf("%s-%d", sessionName(item), suffix)
	}

	command := []string{"codex"}

	switch {
	case options.Fork != "":
		command = append(command, "fork", "--cd", item.Path, "--", options.Fork)
	case options.ForkPicker:
		command = append(command, "fork", "--all", "--cd", item.Path)
	default:
		command = append(command, "resume")
	}

	window := "repo"
	if options.Fork != "" || options.ForkPicker {
		window = "codex"
	}

	id, err := session.Create(ctx, session.Options{
		Name: name, Directory: item.Path, DisplayName: item.Name,
		CodexDirectory: options.SourceDir, CodexCommand: command, ActiveWindow: window,
	})
	if err != nil {
		return "", fmt.Errorf("set up session: %w", err)
	}

	return id, nil
}
