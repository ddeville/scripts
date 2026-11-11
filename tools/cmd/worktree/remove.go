package main

import (
	"bufio"
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/worktree"
)

func removeCommand(options *settings) *cobra.Command {
	var yes, keepBranch, dryRun bool

	cmd := &cobra.Command{
		Use:     "remove [name|repo/name|path]",
		Aliases: []string{"rm"},
		Short:   "Remove a clean worktree, its merged branch, and matching tmux sessions",
		Args:    cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			item, err := worktree.Resolve(cmd.Context(), options.root, options.directory, target(args))
			if err != nil {
				return fmt.Errorf("resolve worktree: %w", err)
			}

			plan, err := worktree.PlanRemoval(cmd.Context(), item, keepBranch)
			if err != nil {
				return fmt.Errorf("plan removal: %w", err)
			}

			cmd.Printf("Remove worktree: %s\n", display(plan.Worktree.Path))

			if plan.Branch != "" {
				cmd.Printf("Delete branch: %s\n", display(plan.Branch))
			}

			for _, session := range plan.Sessions {
				cmd.Printf("Close tmux session: %s\n", display(session.Name))
			}

			if dryRun {
				return nil
			}

			if !yes {
				cmd.Print("Continue? [y/N] ")
				input := bufio.NewScanner(cmd.InOrStdin())
				input.Scan()

				if err := input.Err(); err != nil {
					return fmt.Errorf("read confirmation: %w", err)
				}

				answer := strings.ToLower(strings.TrimSpace(input.Text()))
				if answer != "y" && answer != "yes" {
					cmd.Println("Aborted.")
					return nil
				}
			}

			if err := worktree.Remove(cmd.Context(), plan); err != nil {
				return fmt.Errorf("remove worktree: %w", err)
			}

			cmd.Println("Removed worktree:", display(item.Path))

			return nil
		},
	}
	cmd.Flags().StringVarP(&options.directory, "directory", "C", options.directory, "source repository or current worktree")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "skip the confirmation prompt")
	cmd.Flags().BoolVar(&keepBranch, "keep-branch", false, "retain the Git branch")
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "show what would be removed")

	return cmd
}
