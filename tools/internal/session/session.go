// Package session creates the shared repo/editor/Codex tmux layout.
package session

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"time"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var errEditor = errors.New("EDITOR is not set")

// Options selects the session directory, commands, and initially selected window.
type Options struct {
	Name           string
	Directory      string
	DisplayName    string
	CodexDirectory string
	CodexCommand   []string
	ActiveWindow   string
}

// CheckTools checks the programs required to create a development session.
func CheckTools() error {
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

// Create starts a session and removes it if window setup fails.
func Create(ctx context.Context, options Options) (string, error) {
	if err := CheckTools(); err != nil {
		return "", err
	}

	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	id, err := tmux.NewSession(ctx, options.Name, "repo", options.Directory)
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

	if options.DisplayName != "" {
		if err := tmux.SetOption(ctx, id, "@display_name", options.DisplayName); err != nil {
			return "", fmt.Errorf("set session display name: %w", err)
		}
	}

	if err := tmux.NewWindow(ctx, id, "editor", options.Directory, os.Getenv("EDITOR")); err != nil {
		return "", fmt.Errorf("create editor window: %w", err)
	}

	command := options.CodexCommand
	if len(command) == 0 {
		command = []string{"codex"}
	}

	if err := tmux.NewWindow(ctx, id, "codex", cmp.Or(options.CodexDirectory, options.Directory), command...); err != nil {
		return "", fmt.Errorf("create Codex window: %w", err)
	}

	if err := tmux.SelectWindow(ctx, id, cmp.Or(options.ActiveWindow, "repo")); err != nil {
		return "", fmt.Errorf("select session window: %w", err)
	}

	ready = true

	return id, nil
}
