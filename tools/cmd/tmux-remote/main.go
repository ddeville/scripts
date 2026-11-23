// Command tmux-remote manages SSH connections and zmx terminals for tmux-session.
package main

import (
	"os"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
	"github.com/ddeville/scripts/tools/internal/remote"
)

func main() {
	root := &cobra.Command{
		Use: "tmux-remote", Short: "Manage remote tmux workspaces",
		SilenceUsage: true, SilenceErrors: true,
	}

	var (
		editor, codex, window bool
		terminal              string
	)

	attach := &cobra.Command{
		Use:   "attach [-- command [args...]]",
		Short: "Attach this pane to a remote terminal",
		RunE: func(cmd *cobra.Command, args []string) error {
			kind := "shell"
			if editor {
				kind = "editor"
			} else if codex {
				kind = "codex"
			}

			return remote.Attach(cmd.Context(), kind, terminal, args)
		},
	}
	attach.Flags().BoolVar(&editor, "editor", false, "launch the remote editor")
	attach.Flags().BoolVar(&codex, "codex", false, "launch Codex")
	attach.Flags().StringVar(&terminal, "terminal", "", "use this workspace terminal name")
	attach.MarkFlagsMutuallyExclusive("editor", "codex")

	closeCmd := &cobra.Command{
		Use:   "close TARGET",
		Short: "Close a remote pane or window",
		Args:  cli.ExactArgs("target"),
		RunE: func(cmd *cobra.Command, args []string) error {
			return remote.Close(cmd.Context(), args[0], window)
		},
	}
	closeCmd.Flags().BoolVar(&window, "window", false, "close every pane in the target window")
	root.AddCommand(
		&cobra.Command{
			Use:   "manage DIRECTORY",
			Short: "Maintain a workspace connection",
			Args:  cli.ExactArgs("directory"),
			RunE: func(cmd *cobra.Command, args []string) error {
				return remote.Manage(cmd.Context(), args[0])
			},
		},
		attach, closeCmd,
		&cobra.Command{
			Use:   "resume TERMINAL",
			Short: "Reattach this pane to a surviving terminal",
			Args:  cli.ExactArgs("terminal"),
			RunE: func(cmd *cobra.Command, args []string) error {
				return remote.Attach(cmd.Context(), "resume", args[0], nil)
			},
		},
	)
	os.Exit(cli.Execute(root))
}
