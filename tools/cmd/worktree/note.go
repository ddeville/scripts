package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

func noteCommand(options *settings) *cobra.Command {
	var message string

	var clearNote, showNote bool

	cmd := &cobra.Command{
		Use:   "note [text]",
		Short: "Edit, show, or clear a worktree's local note",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			hasMessage := cmd.Flags().Changed("message")
			if len(args) != 0 && (hasMessage || clearNote || showNote) {
				return fmt.Errorf("%w: positional note text cannot be combined with --message, --show, or --clear", os.ErrInvalid)
			}

			item, err := worktree.Resolve(cmd.Context(), options.root, options.directory, "")
			if err != nil {
				return fmt.Errorf("resolve worktree: %w", err)
			}

			switch {
			case clearNote:
				return worktree.ClearNote(item.Path)
			case hasMessage:
				return worktree.SetNote(item.Path, message)
			case len(args) != 0:
				return worktree.SetNote(item.Path, args[0])
			case showNote:
				if item.Note != "" {
					if _, err := fmt.Fprintln(cmd.OutOrStdout(), tui.CleanText(item.Note)); err != nil {
						return fmt.Errorf("print worktree note: %w", err)
					}
				}

				return nil
			default:
				return worktree.EditNote(cmd.Context(), item)
			}
		},
	}
	flags := cmd.Flags()
	flags.StringVarP(&options.directory, "directory", "C", options.directory, "path to the worktree")
	flags.StringVarP(&message, "message", "m", "", "replace the note with this message")
	flags.BoolVar(&showNote, "show", false, "print the note")
	flags.BoolVar(&clearNote, "clear", false, "remove the note")
	cmd.MarkFlagsMutuallyExclusive("message", "show", "clear")

	return cmd
}
