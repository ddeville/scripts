package cli

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"syscall"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/tui"
)

// Execute runs a command with graceful signal cancellation and returns its exit code.
func Execute(cmd *cobra.Command) int {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)

	defer signal.Stop(signals)

	finished := make(chan int, 1)

	go func() {
		select {
		case sig := <-signals:
			// Let a second signal force an exit if graceful cleanup gets stuck.
			signal.Stop(signals)
			cancel()

			code := 130
			if sig == syscall.SIGTERM {
				code = 143
			}

			finished <- code
		case <-ctx.Done():
			finished <- 0
		}
	}()

	err := cmd.ExecuteContext(ctx)

	cancel()

	if code := <-finished; code != 0 {
		return code
	}

	if err != nil && !errors.Is(err, syscall.EPIPE) {
		cmd.PrintErrf("%s: %s\n", cmd.Name(), tui.CleanLine(err.Error()))
		return 1
	}

	return 0
}
