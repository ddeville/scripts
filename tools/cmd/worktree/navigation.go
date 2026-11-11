package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"text/tabwriter"
	"unicode"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

func listCommand(options *settings) *cobra.Command {
	var asJSON bool

	cmd := &cobra.Command{
		Use:     "list",
		Aliases: []string{"ls"},
		Short:   "List managed worktrees, Git state, and tmux sessions",
		Args:    cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			items, err := listWorktrees(cmd.Context(), options.root)
			if err != nil {
				return fmt.Errorf("list worktrees: %w", err)
			}

			if asJSON {
				if err := json.NewEncoder(cmd.OutOrStdout()).Encode(items); err != nil {
					return fmt.Errorf("write worktrees: %w", err)
				}

				return nil
			}

			output := tabwriter.NewWriter(cmd.OutOrStdout(), 0, 4, 2, ' ', 0)
			if _, err := fmt.Fprintln(output, "REPO\tWORKTREE\tBRANCH\tGIT\tTMUX SESSION\tPATH"); err != nil {
				return fmt.Errorf("write headings: %w", err)
			}

			for _, item := range items {
				if _, err := fmt.Fprintf(output, "%s\t%s\t%s\t%s\t%s\t%s\n", display(item.Repo), display(item.Name),
					display(item.Branch), item.Status, display(item.Session.Name), display(item.Path)); err != nil {
					return fmt.Errorf("write worktree: %w", err)
				}
			}

			if err := output.Flush(); err != nil {
				return fmt.Errorf("write worktree list: %w", err)
			}

			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "output structured worktree data")

	return cmd
}

func openCommand(options *settings) *cobra.Command {
	var noSwitch bool

	cmd := &cobra.Command{
		Use:   "open [name|repo/name|path]",
		Short: "Switch to a worktree's tmux session, creating it if missing",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			item, err := resolveWorktree(cmd.Context(), options.root, options.directory, target(args))
			if err != nil {
				return fmt.Errorf("resolve worktree: %w", err)
			}

			id, err := ensureSession(cmd.Context(), item, sessionOptions{})
			if err != nil {
				return fmt.Errorf("open session: %w", err)
			}

			if noSwitch {
				return nil
			}

			return tmux.SwitchSession(cmd.Context(), id, "")
		},
	}
	cmd.Flags().StringVarP(&options.directory, "directory", "C", options.directory, "source repository or current worktree")
	cmd.Flags().BoolVar(&noSwitch, "no-switch", false, "ensure a session exists without switching or attaching")

	return cmd
}

func target(args []string) string {
	if len(args) == 0 {
		return ""
	}

	return args[0]
}

func display(value string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return ' '
		}

		return r
	}, value)
}
