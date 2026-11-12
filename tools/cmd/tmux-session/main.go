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
	cmd := command()
	err := cmd.ExecuteContext(ctx)
	failed := err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE)

	stop()

	if failed {
		fmt.Fprintln(os.Stderr, cmd.Name()+":", tui.CleanLine(err.Error()))
		os.Exit(1)
	}
}

func command() *cobra.Command {
	var (
		name     string
		noSwitch bool
	)

	cmd := &cobra.Command{
		Use:           "tmux-session <path>",
		Short:         "Create a tmux session with repo, editor, and Codex windows",
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

			if err := session.CheckTools(); err != nil {
				return fmt.Errorf("check session tools: %w", err)
			}

			sessionName := filepath.Base(directory)
			if cmd.Flags().Changed("name") {
				sessionName = name
			}

			sessionName, err = chooseName(cmd, sessionName)
			if err != nil {
				return fmt.Errorf("choose session name: %w", err)
			}

			id, err := session.Create(cmd.Context(), session.Options{Name: sessionName, Directory: directory})
			if err != nil {
				return fmt.Errorf("set up session: %w", err)
			}

			cmd.Printf("Created tmux session: %s\nWorkdir: %s\n", tui.CleanLine(sessionName), tui.CleanLine(directory))

			if noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), id, "")
		},
	}
	cmd.SetOut(os.Stdout)
	cmd.Flags().StringVarP(&name, "name", "n", "", "session name (defaults to the directory name)")
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
