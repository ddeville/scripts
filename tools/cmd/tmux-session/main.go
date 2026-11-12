// Command tmux-session creates a repo/editor/Codex session for any directory.
package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"slices"
	"syscall"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/session"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := command().ExecuteContext(ctx)
	failed := err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE)

	stop()

	if failed {
		fmt.Fprintln(os.Stderr, "tmux-session:", tui.CleanLine(err.Error()))
		os.Exit(1)
	}
}

func command() *cobra.Command {
	var noSwitch bool

	cmd := &cobra.Command{
		Use:           "tmux-session <path> [session-name]",
		Short:         "Create a tmux session with repo, editor, and Codex windows",
		Args:          cobra.RangeArgs(1, 2),
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(cmd *cobra.Command, args []string) error {
			directory, err := resolveDirectory(args[0])
			if err != nil {
				return err
			}

			if err := session.CheckTools(); err != nil {
				return fmt.Errorf("check session tools: %w", err)
			}

			name := filepath.Base(directory)
			if len(args) == 2 {
				name = args[1]
			}

			name, err = chooseName(cmd, name)
			if err != nil {
				return fmt.Errorf("choose session name: %w", err)
			}

			id, err := session.Create(cmd.Context(), session.Options{Name: name, Directory: directory})
			if err != nil {
				return fmt.Errorf("set up session: %w", err)
			}

			cmd.Printf("Created tmux session: %s\nWorkdir: %s\n", tui.CleanLine(name), tui.CleanLine(directory))

			if noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), id, "")
		},
	}
	cmd.SetOut(os.Stdout)
	cmd.Flags().BoolVar(&noSwitch, "no-switch", false, "create the session without switching or attaching")

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

func chooseName(cmd *cobra.Command, name string) (string, error) {
	sessions, err := tmux.ListSessions(cmd.Context())
	if err != nil {
		return "", fmt.Errorf("list sessions: %w", err)
	}

	input := bufio.NewScanner(cmd.InOrStdin())

	for {
		switch {
		case name == "":
			cmd.PrintErrln("Session name cannot be empty.")
		case slices.ContainsFunc(sessions, func(s tmux.Session) bool { return s.Name == name }):
			cmd.PrintErrf("tmux session %q already exists.\n", tui.CleanLine(name))
		default:
			return name, nil
		}

		cmd.Print("Enter a different session name: ")

		if !input.Scan() {
			if err := input.Err(); err != nil {
				return "", fmt.Errorf("read session name: %w", err)
			}

			return "", fmt.Errorf("%w: provide an unused session name", os.ErrInvalid)
		}

		name = input.Text()
	}
}
