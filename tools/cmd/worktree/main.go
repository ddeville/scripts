// Command worktree manages linked checkouts, tmux sessions, and Codex forks.
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

func main() {
	os.Exit(cli.Execute(command()))
}

type settings struct{ root, directory string }

func command() *cobra.Command {
	options := &settings{root: worktree.DefaultRoot(), directory: "."}

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
	cmd.AddCommand(createCommand(options), listCommand(options), openCommand(options), removeCommand(options))

	return cmd
}
