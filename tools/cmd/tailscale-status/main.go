//go:build linux

// Command tailscale-status reports local Tailscale state as JSON.
package main

import (
	"os"

	"github.com/spf13/cobra"
	"tailscale.com/client/local"

	"github.com/ddeville/scripts/tools/internal/cli"
)

func main() {
	os.Exit(cli.Execute(command()))
}

func command() *cobra.Command {
	var watch bool

	cmd := &cobra.Command{
		Use:           "tailscale-status",
		Short:         "Output local Tailscale status as JSON",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return run(cmd.Context(), &local.Client{}, os.Stdout, watch)
		},
	}
	cmd.Flags().BoolVar(&watch, "watch", false, "stream status changes until interrupted")

	return cmd
}
