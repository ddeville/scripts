package main

import (
	"errors"
	"fmt"
	"io"
	"strings"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

var errInvalidBranchAction = errors.New("--branch must be delete-merged, keep, or force-delete")

func removeCommand(options *settings) *cobra.Command {
	var yes, dryRun bool

	var branchAction string

	cmd := &cobra.Command{
		Use:     "remove [name|repo/name|path]",
		Aliases: []string{"rm"},
		Short:   "Remove a clean worktree, its merged branch, and matching tmux sessions",
		Args:    cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			switch branchAction {
			case "delete-merged", "keep", "force-delete":
			default:
				return fmt.Errorf("%w, got %q", errInvalidBranchAction, branchAction)
			}

			item, err := worktree.Resolve(cmd.Context(), options.root, options.directory, target(args))
			if err != nil {
				return fmt.Errorf("resolve worktree: %w", err)
			}

			plan, err := worktree.PlanRemovalWithBranchOptions(cmd.Context(), item, branchAction == "keep", branchAction == "force-delete")
			if err != nil {
				return fmt.Errorf("plan removal: %w", err)
			}

			cmd.Printf("Remove worktree: %s\n", display(plan.Worktree.Path))

			switch {
			case plan.KeptBranch != "":
				cmd.Printf("Keep branch: %s\n", display(plan.KeptBranch))
			case plan.Branch != "" && branchAction == "force-delete":
				cmd.Printf("Force-delete branch: %s\n", display(plan.Branch))
			case plan.Branch != "":
				cmd.Printf("Delete branch: %s\n", display(plan.Branch))
			default:
				cmd.Println("Branch: detached HEAD")
			}

			for _, session := range plan.Sessions {
				cmd.Printf("Close tmux session: %s\n", display(session.Name))
			}

			if dryRun {
				return nil
			}

			if !yes {
				cmd.Print("Continue? [y/N] ")

				input, err := cli.NewInput(cmd.InOrStdin())
				if err != nil {
					return fmt.Errorf("prepare confirmation: %w", err)
				}
				defer func() { _ = input.Close() }()

				answer, err := input.ReadLine(cmd.Context())
				if err != nil && !errors.Is(err, io.EOF) {
					return fmt.Errorf("read confirmation: %w", err)
				}

				answer = strings.ToLower(strings.TrimSpace(answer))
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
	cmd.Flags().StringVar(&branchAction, "branch", "delete-merged", "local branch action (delete-merged, keep, or force-delete)")
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "show what would be removed")

	return cmd
}
