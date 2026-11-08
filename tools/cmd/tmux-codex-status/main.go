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

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := command().ExecuteContext(ctx); err != nil && ctx.Err() == nil && !errors.Is(err, syscall.EPIPE) {
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

	var watch bool
	var seconds float64
	var output, detailID string
	status := &cobra.Command{
		Use:   "status",
		Short: "Output agent status as JSON",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			interval := time.Duration(seconds * float64(time.Second))
			if interval <= 0 {
				return fmt.Errorf("interval must be a positive number of seconds")
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
		var data any
		var err error
		if detailID == "" {
			data = collect(requestCtx)
		} else {
			data, err = detail(requestCtx, detailID)
		}
		cancel()
		if ctx.Err() != nil {
			return ctx.Err()
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
			return ctx.Err()
		case <-time.After(max(0, interval-time.Since(started))):
		}
	}
}

func encodeJSON(output io.Writer, data any) error {
	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)
	return encoder.Encode(data)
}

func writeJSON(data any, path string) error {
	if path == "" {
		return encodeJSON(os.Stdout, data)
	}
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0700); err != nil {
		return err
	}
	file, err := os.CreateTemp(directory, "."+filepath.Base(path)+".*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if err := encodeJSON(file, data); err != nil {
		file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}
