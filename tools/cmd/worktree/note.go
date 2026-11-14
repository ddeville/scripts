package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

func noteCommand(options *settings) *cobra.Command {
	var clearNote bool

	cmd := &cobra.Command{
		Use:   "note [text]",
		Short: "Show, replace, or clear a worktree's local note",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if clearNote && len(args) != 0 {
				return fmt.Errorf("%w: --clear cannot be combined with note text", os.ErrInvalid)
			}

			item, err := worktree.Resolve(cmd.Context(), options.root, options.directory, "")
			if err != nil {
				return fmt.Errorf("resolve worktree: %w", err)
			}

			switch {
			case clearNote:
				return worktree.ClearNote(item.Path)
			case len(args) != 0:
				return worktree.SetNote(item.Path, args[0])
			case item.Note != "":
				if _, err := fmt.Fprintln(cmd.OutOrStdout(), tui.CleanText(item.Note)); err != nil {
					return fmt.Errorf("print worktree note: %w", err)
				}
			}

			return nil
		},
	}
	cmd.Flags().StringVarP(&options.directory, "directory", "C", options.directory, "path to the worktree")
	cmd.Flags().BoolVar(&clearNote, "clear", false, "remove the note")

	return cmd
}
