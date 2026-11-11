// Command tmux-agent-status displays and navigates local agents in tmux.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/cobra"
)

var errInvalidInterval = errors.New("interval must be a positive number of seconds")

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := command().ExecuteContext(ctx)
	failed := err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE)

	stop()

	if failed {
		fmt.Fprintln(os.Stderr, "tmux-agent-status:", cleanText(err.Error()))
		os.Exit(1)
	}
}

func command() *cobra.Command {
	root := &cobra.Command{
		Use:           "tmux-agent-status",
		Short:         "Navigate agents in the current tmux server",
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	var client, pane string

	picker := &cobra.Command{
		Use:   "picker",
		Short: "Open the interactive agent picker",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return runPicker(cmd.Context(), client, pane)
		},
	}
	picker.Flags().StringVar(&client, "client", "", "tmux client to switch")
	picker.Flags().StringVar(&pane, "pane", os.Getenv("TMUX_PANE"), "tmux pane to initially select")

	var (
		watch            bool
		seconds          float64
		output, detailID string
	)

	status := &cobra.Command{
		Use:   "status",
		Short: "Output agent status as JSON",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			interval := time.Duration(seconds * float64(time.Second))
			if interval <= 0 {
				return errInvalidInterval
			}

			return runStatus(cmd.Context(), watch, interval, output, detailID)
		},
	}
	status.Flags().BoolVar(&watch, "watch", false, "stream status snapshots")
	status.Flags().Float64Var(&seconds, "interval", 2, "seconds between snapshots")
	status.Flags().StringVar(&output, "output", "", "atomically write JSON to this file")
	status.Flags().StringVar(&detailID, "detail", "", "read a conversation's recent activity")
	status.MarkFlagsMutuallyExclusive("watch", "detail")

	open := &cobra.Command{
		Use:   "open THREAD_ID",
		Short: "Open an agent in the only attached tmux client",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return openThread(cmd.Context(), args[0])
		},
	}
	root.AddCommand(picker, status, open)

	return root
}
