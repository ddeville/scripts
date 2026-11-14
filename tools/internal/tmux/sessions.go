package tmux

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

// Session identifies a tmux session by its ID and starting directory.
type Session struct {
	ID   string `json:"id,omitempty"`
	Name string `json:"name,omitempty"`
	Path string `json:"path,omitempty"`
}

// ListSessions returns sessions sorted by name, or none when no server is running.
func ListSessions(ctx context.Context) ([]Session, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	output, err := run(ctx, "list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_path}")
	if err != nil {
		if errors.Is(err, exec.ErrNotFound) || strings.Contains(output, "no server running") || strings.Contains(output, "No such file or directory") {
			return nil, nil
		}

		return nil, err
	}

	var sessions []Session

	for line := range strings.SplitSeq(strings.TrimSuffix(output, "\n"), "\n") {
		fields := strings.SplitN(line, "\t", 3)
		if len(fields) != 3 {
			continue
		}

		path := fields[2]
		if resolved, err := filepath.EvalSymlinks(path); err == nil {
			path = resolved
		}

		sessions = append(sessions, Session{ID: fields[0], Name: fields[1], Path: filepath.Clean(path)})
	}

	slices.SortFunc(sessions, func(a, b Session) int { return cmp.Compare(a.Name, b.Name) })

	return sessions, nil
}

// NewSession creates a detached session with one window and returns its ID.
// The initial program waits until a client attaches.
func NewSession(ctx context.Context, name, window, path string) (string, error) {
	args := append([]string{"new-session", "-d", "-P", "-F", "#{session_id}", "-s", name, "-n", window, "-c", path}, attachedCommand()...)

	output, err := run(ctx, args...)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(output), nil
}

// SetOption sets an option on a session.
func SetOption(ctx context.Context, session, option, value string) error {
	_, err := run(ctx, "set-option", "-t", session, option, value)
	return err
}

// NewWindow creates a window without selecting it. The command waits until the
// session has an attached client. Multiple command arguments bypass shell parsing.
func NewWindow(ctx context.Context, session, name, path string, command ...string) error {
	args := append([]string{"new-window", "-d", "-t", session + ":", "-n", name, "-c", path}, attachedCommand(command...)...)
	_, err := run(ctx, args...)

	return err
}

// SelectWindow selects a window within a session.
func SelectWindow(ctx context.Context, session, window string) error {
	_, err := run(ctx, "select-window", "-t", session+":"+window)
	return err
}

// KillSession closes a session and its windows.
func KillSession(ctx context.Context, id string) error {
	_, err := run(ctx, "kill-session", "-t", id)
	return err
}

// SwitchSession switches a tmux client, or attaches when run outside tmux.
func SwitchSession(ctx context.Context, id, client string) error {
	if client != "" || os.Getenv("TMUX") != "" {
		return switchClient(ctx, id, client)
	}

	cmd := exec.CommandContext(ctx, "tmux", "attach-session", "-t", id) // #nosec G204 -- id is the separate value of -t, obtained from tmux itself.
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("attach tmux session: %w", err)
	}

	return nil
}
