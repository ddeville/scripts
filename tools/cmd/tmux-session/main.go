// Command tmux-session opens a local or remote project in tmux.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
	"github.com/ddeville/scripts/tools/internal/session"
	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

func main() {
	os.Exit(cli.Execute(command()))
}

func command() *cobra.Command {
	var (
		name, host, retry          string
		launch, reply, closeTarget string
		noSwitch                   bool
	)

	cmd := &cobra.Command{
		Use:           "tmux-session <path>",
		Short:         "Open a project in tmux, creating repo, editor, and Codex windows on first use",
		Example:       "  tmux-session .\n  tmux-session ~/src/project --name my-project\n  tmux-session --no-switch . -n scratch\n  tmux-session --host devbox work/api",
		Args:          cobra.MaximumNArgs(1),
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				if retry != "" {
					master, err := sshmux.ForSession(host, retry)
					if err != nil {
						return fmt.Errorf("find session connection: %w", err)
					}

					return reconnect(cmd.Context(), master)
				}

				if launch != "" {
					code, err := attachPane(cmd.Context(), launch, reply)
					if err != nil {
						cmd.PrintErrln(tui.CleanLine(err.Error()))
					}

					os.Exit(code)
				}

				if closeTarget != "" {
					return closePanes(cmd.Context(), closeTarget)
				}

				if err := cmd.Help(); err != nil {
					return fmt.Errorf("show help: %w", err)
				}

				return nil
			}

			if cmd.Flags().Changed("name") && name == "" {
				return fmt.Errorf("%w: session name cannot be empty", os.ErrInvalid)
			}

			var (
				target  tmux.Session
				created bool
				err     error
			)

			if cmd.Flags().Changed("host") {
				target, created, err = openRemote(cmd.Context(), host, args[0], name)
			} else {
				target, created, err = openSession(cmd.Context(), args[0], name)
			}

			if err != nil {
				return fmt.Errorf("open session: %w", err)
			}

			action := "Reusing"
			if created {
				action = "Created"
			}

			cmd.Printf("%s tmux session: %s\nWorkdir: %s\n", action, tui.CleanLine(target.Name), tui.CleanLine(target.Path))

			if noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), target.ID, "")
		},
	}
	cmd.SetOut(os.Stdout)
	cmd.Flags().StringVar(&host, "host", "", "SSH destination (relative paths start in the remote home directory)")
	cmd.Flags().StringVarP(&name, "name", "n", "", "open a named workspace for this directory (defaults to the directory name)")
	cmd.Flags().BoolVar(&noSwitch, "no-switch", false, "find or create the session without switching or attaching")
	cmd.Flags().StringVar(&launch, "remote-pane", "", "launch or resume one pane")
	cmd.Flags().StringVar(&reply, "pane-reply", "", "report pane startup to the caller")
	cmd.Flags().Lookup("pane-reply").Hidden = true
	cmd.Flags().StringVar(&retry, "reconnect", "", "recover interrupted panes of a remote session")
	cmd.Flags().Lookup("reconnect").Hidden = true
	cmd.Flags().StringVar(&closeTarget, "remote-close", "", "close a pane or window by ID")
	cmd.Flags().Lookup("remote-pane").Hidden = true
	cmd.Flags().Lookup("remote-close").Hidden = true

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
func lockOpen(ctx context.Context) (*os.File, error) {
	dir, err := sshmux.CacheDir()
	if err != nil {
		return nil, fmt.Errorf("locate tmux session cache: %w", err)
	}

	return lockFile(ctx, filepath.Join(dir, "open.lock"))
}

// Only one operation at a time may use the connection's management slot.
func lockMaster(ctx context.Context, master sshmux.Master) (*os.File, error) {
	return lockFile(ctx, master.Socket+".lock")
}

func lockFile(ctx context.Context, filename string) (*os.File, error) {
	lock, err := os.OpenFile(filename, os.O_CREATE|os.O_RDWR, 0o600) // #nosec G304 -- Internal lock file in a private directory.
	if err != nil {
		return nil, fmt.Errorf("open session lock: %w", err)
	}

	for ctx.Err() == nil {
		err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			return lock, nil
		}

		if !errors.Is(err, syscall.EWOULDBLOCK) {
			_ = lock.Close()
			return nil, fmt.Errorf("acquire session lock: %w", err)
		}

		select {
		case <-ctx.Done():
		case <-time.After(25 * time.Millisecond):
		}
	}

	_ = lock.Close()

	return nil, fmt.Errorf("wait for session lock: %w", ctx.Err())
}

func openSession(ctx context.Context, path, name string) (tmux.Session, bool, error) {
	directory, err := resolveDirectory(path)
	if err != nil {
		return tmux.Session{}, false, err
	}

	if name == "" {
		name = filepath.Base(directory)
	}

	lock, err := lockOpen(ctx)
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
		if s.Remote == "" && s.Workspace == workspace {
			return s, false, nil
		}
	}

	for _, s := range sessions {
		if s.Remote == "" && s.Workspace == "" && s.Path == directory && s.Name == name {
			if err := tmux.SetOption(ctx, s.ID, tmux.WorkspaceOption, workspace); err != nil {
				return tmux.Session{}, false, fmt.Errorf("identify existing workspace: %w", err)
			}

			return s, false, nil
		}
	}

	displayName := tmux.AvailableName(sessions, name)

	id, err := session.Create(ctx, session.Options{Name: displayName, Directory: directory, Workspace: workspace})
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("create workspace: %w", err)
	}

	return tmux.Session{ID: id, Name: displayName, Path: directory}, true, nil
}
