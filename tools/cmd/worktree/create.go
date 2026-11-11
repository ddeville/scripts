package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tmux"
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
		Use:   "create <name>",
		Short: "Create a worktree, tmux session, editor, and forked Codex thread",
		Args:  cobra.ExactArgs(1),
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

			if !noTmux {
				if err := checkSessionTools(); err != nil {
					return fmt.Errorf("check session tools: %w", err)
				}
			}

			item, err := createWorktree(cmd.Context(), options.root, createOptions{
				Directory: options.directory, Name: args[0], Base: base,
			})
			if err != nil {
				return fmt.Errorf("create worktree: %w", err)
			}

			cmd.Printf("Created worktree: %s\nBranch: %s\n", item.Path, item.Branch)

			if noTmux {
				return nil
			}

			id, err := ensureSession(cmd.Context(), item, sessionOptions{
				Fork: fork, ForkPicker: true, SourceDir: options.directory,
			})
			if err != nil {
				return fmt.Errorf("worktree created at %s, but session setup failed: %w", item.Path, err)
			}

			if noSwitch {
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
