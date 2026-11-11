// Command worktree manages linked checkouts, tmux sessions, and Codex forks.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := command().ExecuteContext(ctx)
	failed := err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE)

	stop()

	if failed {
		fmt.Fprintln(os.Stderr, "worktree:", tui.CleanLine(err.Error()))
		os.Exit(1)
	}
}

type settings struct{ root, directory string }

func command() *cobra.Command {
	options := &settings{root: os.Getenv("GIT_SRC_WORKTREE_DIR"), directory: "."}
	if options.root == "" {
		home, _ := os.UserHomeDir()
		options.root = filepath.Join(home, "src/worktrees")
	}

	cmd := &cobra.Command{
		Use:           "worktree",
		Short:         "Manage worktrees, tmux sessions, and Codex forks",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		SilenceUsage:  true,
		PersistentPreRunE: func(_ *cobra.Command, _ []string) error {
			var err error

			options.root, err = filepath.Abs(options.root)
			if err != nil {
				return fmt.Errorf("resolve worktree directory: %w", err)
			}

			options.directory, err = filepath.Abs(options.directory)
			if err != nil {
				return fmt.Errorf("resolve source directory: %w", err)
			}

			return nil
		},
	}
	cmd.SetOut(os.Stdout)
	cmd.PersistentFlags().StringVar(&options.root, "root", options.root, "directory containing repo/worktree folders")
	cmd.AddCommand(createCommand(options), listCommand(options), openCommand(options), removeCommand(options), tuiCommand(options))

	return cmd
}

func tuiCommand(options *settings) *cobra.Command {
	var client string

	cmd := &cobra.Command{
		Use:   "tui",
		Short: "Create, open, and remove worktrees interactively",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return runTUI(cmd.Context(), options.root, options.directory, client)
		},
	}
	cmd.Flags().StringVar(&client, "client", "", "tmux client to switch")
	cmd.Flags().StringVarP(&options.directory, "directory", "C", options.directory, "initial source repository or worktree")

	return cmd
}
