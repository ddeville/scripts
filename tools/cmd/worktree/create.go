package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

var (
	errThread = errors.New("--fork=current requires CODEX_THREAD_ID from a running Codex session")
	errFork   = errors.New("--fork cannot be used with --no-tmux")
)

func createCommand(options *settings) *cobra.Command {
	var (
		base, fork       string
		noTmux, noSwitch bool
	)

	cmd := &cobra.Command{
		Use:     "create <name>",
		Aliases: []string{"new"},
		Short:   "Create a worktree and open its tmux session",
		Example: "  wt create --base master --fork=current my-feature",
		Args:    cli.ExactArgs("worktree name"),
		RunE: func(cmd *cobra.Command, args []string) error {
			if cmd.Flags().Changed("fork") && noTmux {
				return errFork
			}

			if cmd.Flags().Changed("fork") && fork == "" {
				return fmt.Errorf("%w: --fork needs 'current' or a thread ID", os.ErrInvalid)
			}

			thread := fork
			if thread == "current" {
				thread = os.Getenv("CODEX_THREAD_ID")
				if thread == "" {
					return errThread
				}
			}

			item, id, err := worktree.Create(cmd.Context(), options.root, worktree.CreateOptions{
				Directory: options.directory, Name: args[0], Base: base, Fork: thread, NoTmux: noTmux,
			})
			if err != nil {
				return fmt.Errorf("create workspace: %w", err)
			}

			cmd.Printf("Created worktree: %s\nBranch: %s\n", display(item.Path), display(item.Branch))

			if noTmux || noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), id, "")
		},
	}
	flags := cmd.Flags()
	flags.StringVarP(&options.directory, "directory", "C", options.directory, "source repository or current worktree")
	flags.StringVar(&base, "base", "", "base ref. If omitted, use HEAD and require a clean source checkout")
	flags.StringVar(&fork, "fork", "", "Codex thread to fork (current or a thread ID). Omit to open the picker")
	flags.BoolVar(&noTmux, "no-tmux", false, "create only the Git worktree and branch")
	flags.BoolVar(&noSwitch, "no-switch", false, "prepare the tmux session without switching or attaching")

	return cmd
}
