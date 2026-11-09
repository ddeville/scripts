// Command tmux-codex-status displays and navigates local Codex agents in tmux.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
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
		fmt.Fprintln(os.Stderr, "tmux-codex-status:", err)
		os.Exit(1)
	}
}

func command() *cobra.Command {
	root := &cobra.Command{
		Use:           "tmux-codex-status",
		Short:         "Navigate Codex agents in the current tmux server",
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	var client string

	picker := &cobra.Command{
		Use:   "picker",
		Short: "Open the interactive agent picker",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return runPicker(cmd.Context(), client)
		},
	}
	picker.Flags().StringVar(&client, "client", "", "tmux client to switch")

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
	root.AddCommand(picker, status)

	return root
}

func runStatus(ctx context.Context, watch bool, interval time.Duration, output, detailID string) error {
	for {
		started := time.Now()
		requestCtx, cancel := context.WithTimeout(ctx, 8*time.Second)

		var (
			data any
			err  error
		)

		if detailID == "" {
			data = collect(requestCtx)
		} else {
			data, err = detail(requestCtx, detailID)
		}

		cancel()

		if ctx.Err() != nil {
			return fmt.Errorf("collect status: %w", ctx.Err())
		}

		if err != nil {
			return err
		}

		if err := writeJSON(data, output); err != nil {
			return err
		}

		if !watch {
			return nil
		}

		select {
		case <-ctx.Done():
			return fmt.Errorf("watch status: %w", ctx.Err())
		case <-time.After(max(0, interval-time.Since(started))):
		}
	}
}

func encodeJSON(output io.Writer, data any) error {
	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)

	if err := encoder.Encode(data); err != nil {
		return fmt.Errorf("encode status: %w", err)
	}

	return nil
}

func writeJSON(data any, path string) error {
	if path == "" {
		return encodeJSON(os.Stdout, data)
	}

	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create output directory: %w", err)
	}

	file, err := os.CreateTemp(directory, "."+filepath.Base(path)+".*")
	if err != nil {
		return fmt.Errorf("create snapshot file: %w", err)
	}
	defer func() { _ = os.Remove(file.Name()) }()

	if err := encodeJSON(file, data); err != nil {
		_ = file.Close()
		return err
	}

	if err := file.Close(); err != nil {
		return fmt.Errorf("close snapshot file: %w", err)
	}

	if err := os.Rename(file.Name(), path); err != nil {
		return fmt.Errorf("publish snapshot: %w", err)
	}

	return nil
}
