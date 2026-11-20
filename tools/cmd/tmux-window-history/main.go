// Command tmux-window-history records and navigates each tmux client's window visits.
package main

import (
	"os"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
)

func main() {
	os.Exit(cli.Execute(command()))
}

func command() *cobra.Command {
	root := &cobra.Command{
		Use:           "tmux-window-history",
		Short:         "Record and navigate tmux window history",
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	var socketPath string
	root.PersistentFlags().StringVarP(&socketPath, "socket", "S", "", "tmux server socket path")
	cobra.CheckErr(root.MarkPersistentFlagRequired("socket"))

	root.AddCommand(
		&cobra.Command{
			Use:   "back CLIENT",
			Short: "Return to the previous visited window",
			Args:  cli.ExactArgs("client"),
			RunE: func(cmd *cobra.Command, args []string) error {
				return socket(socketPath).moveClient(cmd.Context(), args[0], backward)
			},
		},
		&cobra.Command{
			Use:   "forward CLIENT",
			Short: "Move forward in window history",
			Args:  cli.ExactArgs("client"),
			RunE: func(cmd *cobra.Command, args []string) error {
				return socket(socketPath).moveClient(cmd.Context(), args[0], forward)
			},
		},
		&cobra.Command{
			Use:   "forget CLIENT",
			Short: "Discard a client's window history",
			Args:  cli.ExactArgs("client"),
			RunE: func(cmd *cobra.Command, args []string) error {
				return socket(socketPath).forgetClient(cmd.Context(), args[0])
			},
		},
		&cobra.Command{
			Use:   "record",
			Short: "Record each attached client's current window",
			Args:  cobra.NoArgs,
			RunE: func(cmd *cobra.Command, _ []string) error {
				return socket(socketPath).update(cmd.Context(), recordVisits)
			},
		},
		&cobra.Command{
			Use:   "sync",
			Short: "Apply queued tmux history events",
			Args:  cobra.NoArgs,
			RunE: func(cmd *cobra.Command, _ []string) error {
				return socket(socketPath).update(cmd.Context(), nil)
			},
		},
	)

	return root
}
