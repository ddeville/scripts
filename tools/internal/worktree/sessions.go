package worktree

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"slices"
	"strings"
	"time"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var errEditor = errors.New("EDITOR is not set")

type sessionOptions struct {
	Fork       string
	ForkPicker bool
	SourceDir  string
}

func checkSessionTools() error {
	if _, err := exec.LookPath("tmux"); err != nil {
		return fmt.Errorf("find tmux: %w", err)
	}

	if os.Getenv("EDITOR") == "" {
		return errEditor
	}

	if _, err := exec.LookPath("codex"); err != nil {
		return fmt.Errorf("find Codex: %w", err)
	}

	return nil
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

	if err := checkSessionTools(); err != nil {
		return "", err
	}

	name := sessionName(item)
	for suffix := 2; slices.ContainsFunc(sessions, func(s tmux.Session) bool { return s.Name == name }); suffix++ {
		name = fmt.Sprintf("%s-%d", sessionName(item), suffix)
	}

	id, err := tmux.NewSession(ctx, name, "repo", item.Path)
	if err != nil {
		return "", fmt.Errorf("create session: %w", err)
	}

	ready := false

	defer func() {
		if !ready {
			cleanup, stop := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
			defer stop()

			_ = tmux.KillSession(cleanup, id)
		}
	}()

	if err := tmux.SetOption(ctx, id, "@display_name", item.Name); err != nil {
		return "", fmt.Errorf("set session display name: %w", err)
	}

	if err := tmux.NewWindow(ctx, id, "editor", item.Path, os.Getenv("EDITOR")); err != nil {
		return "", fmt.Errorf("create editor window: %w", err)
	}

	command := []string{"codex"}
	if options.Fork != "" {
		command = append(command, "fork", "--cd", item.Path, "--", options.Fork)
	} else if options.ForkPicker {
		command = append(command, "fork", "--all", "--cd", item.Path)
	}

	source := options.SourceDir
	if source == "" {
		source = item.Path
	}

	if err := tmux.NewWindow(ctx, id, "codex", source, command...); err != nil {
		return "", fmt.Errorf("create Codex window: %w", err)
	}

	window := "repo"
	if options.Fork != "" || options.ForkPicker {
		window = "codex"
	}

	if err := tmux.SelectWindow(ctx, id, window); err != nil {
		return "", fmt.Errorf("select session window: %w", err)
	}

	ready = true

	return id, nil
}
