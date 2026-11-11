// Command tmux-agent-status navigates agents and manages worktrees in one tmux TUI.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tui"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

var errInvalidInterval = errors.New("interval must be a positive number of seconds")

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := command().ExecuteContext(ctx)
	failed := err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE)

	stop()

	if failed {
		fmt.Fprintln(os.Stderr, "tmux-agent-status:", tui.CleanText(err.Error()))
		os.Exit(1)
	}
}

func command() *cobra.Command {
	root := &cobra.Command{
		Use:           "tmux-agent-status",
		Short:         "Navigate agents and worktrees in the current tmux server",
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	options := tuiOptions{}

	var initialArea string

	picker := &cobra.Command{
		Use:   "tui",
		Short: "Open the Agents and Worktrees areas",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			options.area = area(initialArea)
			if options.area != agentsArea && options.area != worktreesArea {
				return fmt.Errorf("%w: --area must be agents or worktrees", os.ErrInvalid)
			}

			var err error

			options.root, err = filepath.Abs(options.root)
			if err != nil {
				return fmt.Errorf("resolve worktree directory: %w", err)
			}

			options.directory, err = filepath.Abs(options.directory)
			if err != nil {
				return fmt.Errorf("resolve source directory: %w", err)
			}

			return runTUI(cmd.Context(), options)
		},
	}
	picker.Flags().StringVar(&initialArea, "area", "agents", "initial area: agents or worktrees")
	picker.Flags().StringVar(&options.client, "client", "", "tmux client to switch")
	picker.Flags().StringVar(&options.pane, "pane", os.Getenv("TMUX_PANE"), "originating tmux pane and default conversation")
	picker.Flags().StringVar(&options.root, "root", worktree.DefaultRoot(), "directory containing repo/worktree folders")
	picker.Flags().StringVarP(&options.directory, "directory", "C", ".", "initial source repository or worktree")

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
