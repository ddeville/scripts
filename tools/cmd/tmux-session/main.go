// Command tmux-session opens a local project in tmux.
package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"syscall"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
	"github.com/ddeville/scripts/tools/internal/session"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

func main() {
	os.Exit(cli.Execute(command()))
}

func command() *cobra.Command {
	var (
		name     string
		noSwitch bool
	)

	cmd := &cobra.Command{
		Use:           "tmux-session <path>",
		Short:         "Open a project in tmux, creating repo, editor, and Codex windows on first use",
		Example:       "  tmux-session .\n  tmux-session ~/src/project --name my-project\n  tmux-session --no-switch . -n scratch",
		Args:          cobra.MaximumNArgs(1),
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				if err := cmd.Help(); err != nil {
					return fmt.Errorf("show help: %w", err)
				}

				return nil
			}

			directory, err := resolveDirectory(args[0])
			if err != nil {
				return err
			}

			sessionName := filepath.Base(directory)

			if cmd.Flags().Changed("name") {
				if name == "" {
					return fmt.Errorf("%w: session name cannot be empty", os.ErrInvalid)
				}

				sessionName = name
			}

			target, created, err := openSession(cmd.Context(), directory, sessionName)
			if err != nil {
				return fmt.Errorf("open session: %w", err)
			}

			action := "Reusing"
			if created {
				action = "Created"
			}

			cmd.Printf("%s tmux session: %s\nWorkdir: %s\n", action, tui.CleanLine(target.Name), tui.CleanLine(directory))

			if noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), target.ID, "")
		},
	}
	cmd.SetOut(os.Stdout)
	cmd.Flags().StringVarP(&name, "name", "n", "", "open a named workspace for this directory (defaults to the directory name)")
	cmd.Flags().BoolVar(&noSwitch, "no-switch", false, "find or create the session without switching or attaching")

	return cmd
}

func resolveDirectory(path string) (string, error) {
	directory, err := filepath.Abs(path)
	if err != nil {
		return "", fmt.Errorf("resolve directory: %w", err)
	}

	directory, err = filepath.EvalSymlinks(directory)
	if err != nil {
		return "", fmt.Errorf("resolve directory: %w", err)
	}

	info, err := os.Stat(directory)
	if err != nil {
		return "", fmt.Errorf("read directory: %w", err)
	}

	if !info.IsDir() {
		return "", fmt.Errorf("%w: not a directory: %s", os.ErrInvalid, directory)
	}

	return directory, nil
}

// lockOpen serializes lookup and layout creation, including the first tmux server startup.
func lockOpen() (*os.File, error) {
	cache, err := os.UserCacheDir()
	if err != nil {
		return nil, fmt.Errorf("locate cache directory: %w", err)
	}

	lockDir := filepath.Join(cache, "tmux-session")
	if err := os.MkdirAll(lockDir, 0o700); err != nil {
		return nil, fmt.Errorf("create lock directory: %w", err)
	}

	lock, err := os.OpenFile(filepath.Join(lockDir, "open.lock"), os.O_CREATE|os.O_RDWR, 0o600) // #nosec G304 -- Fixed filename in the user's application cache.
	if err != nil {
		return nil, fmt.Errorf("open session lock: %w", err)
	}

	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		_ = lock.Close()
		return nil, fmt.Errorf("lock session creation: %w", err)
	}

	return lock, nil
}

func openSession(ctx context.Context, directory, name string) (tmux.Session, bool, error) {
	lock, err := lockOpen()
	if err != nil {
		return tmux.Session{}, false, err
	}
	defer func() { _ = lock.Close() }()

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("list sessions: %w", err)
	}

	workspace := fmt.Sprintf("%q %q", directory, name)
	for _, s := range sessions {
		if s.Workspace == workspace {
			return s, false, nil
		}
	}

	for _, s := range sessions {
		if s.Workspace == "" && s.Path == directory && s.Name == name {
			if err := tmux.SetOption(ctx, s.ID, tmux.WorkspaceOption, workspace); err != nil {
				return tmux.Session{}, false, fmt.Errorf("identify existing workspace: %w", err)
			}

			return s, false, nil
		}
	}

	displayName := name
	for suffix := 2; slices.ContainsFunc(sessions, func(s tmux.Session) bool { return s.Name == displayName }); suffix++ {
		displayName = fmt.Sprintf("%s-%d", name, suffix)
	}

	id, err := session.Create(ctx, session.Options{Name: displayName, Directory: directory, Workspace: workspace})
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("create workspace: %w", err)
	}

	return tmux.Session{ID: id, Name: displayName}, true, nil
}
