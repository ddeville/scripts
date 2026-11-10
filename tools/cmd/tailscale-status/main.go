// Command tailscale-status reports local Tailscale state as JSON.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/spf13/cobra"
	"tailscale.com/client/local"

	"github.com/ddeville/scripts/tools/internal/tailscalestatus"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := command().ExecuteContext(ctx)
	failed := err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE)

	stop()

	if failed {
		fmt.Fprintln(os.Stderr, "tailscale-status:", err)
		os.Exit(1)
	}
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
			return tailscalestatus.Run(cmd.Context(), &local.Client{}, os.Stdout, watch)
		},
	}
	cmd.Flags().BoolVar(&watch, "watch", false, "stream status changes until interrupted")

	return cmd
}
