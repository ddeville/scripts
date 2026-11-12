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
	errThread = errors.New("CODEX_THREAD_ID is not set; run from Codex or pass --fork <thread-id>")
	errFork   = errors.New("--fork and --fork-current cannot be used with --no-tmux")
)

func createCommand(options *settings) *cobra.Command {
	var (
		base, fork                    string
		forkCurrent, noTmux, noSwitch bool
	)

	cmd := &cobra.Command{
		Use:     "create <name>",
		Aliases: []string{"new"},
		Short:   "Create a worktree, tmux session, editor, and forked Codex thread",
		Args:    cli.ExactArgs("worktree name"),
		RunE: func(cmd *cobra.Command, args []string) error {
			if forkCurrent {
				fork = os.Getenv("CODEX_THREAD_ID")
				if fork == "" {
					return errThread
				}
			}

			if (fork != "" || cmd.Flags().Changed("fork")) && noTmux {
				return errFork
			}

			if cmd.Flags().Changed("fork") && fork == "" {
				return fmt.Errorf("%w: --fork needs a thread ID", os.ErrInvalid)
			}

			item, id, err := worktree.Create(cmd.Context(), options.root, worktree.CreateOptions{
				Directory: options.directory, Name: args[0], Base: base, Fork: fork, NoTmux: noTmux,
			})
			if err != nil {
				return fmt.Errorf("create workspace: %w", err)
			}

			cmd.Printf("Created worktree: %s\nBranch: %s\n", item.Path, item.Branch)

			if noTmux || noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), id, "")
		},
	}
	flags := cmd.Flags()
	flags.StringVarP(&options.directory, "directory", "C", options.directory, "source repository or current worktree")
	flags.StringVar(&base, "base", "", "base commit; an explicit ref leaves source changes behind")
	flags.StringVar(&fork, "fork", "", "Codex thread to fork; otherwise open the thread picker")
	flags.BoolVar(&forkCurrent, "fork-current", false, "fork CODEX_THREAD_ID from the running Codex session")
	flags.BoolVar(&noTmux, "no-tmux", false, "create only the Git worktree and branch")
	flags.BoolVar(&noSwitch, "no-switch", false, "create the session without switching or attaching")
	cmd.MarkFlagsMutuallyExclusive("fork", "fork-current")

	return cmd
}
