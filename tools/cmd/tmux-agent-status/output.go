package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

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
