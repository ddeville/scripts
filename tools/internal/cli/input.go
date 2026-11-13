package cli

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"

	"github.com/muesli/cancelreader"
)

// Input reads prompt lines from a file, pipe, or terminal. Close it after use.
// Cancellation ends a pending pipe or terminal read without closing the input file.
type Input struct {
	scanner *bufio.Scanner
	reader  cancelreader.CancelReader
}

// NewInput prepares file-backed command input for cancellable prompt reads.
func NewInput(reader io.Reader) (*Input, error) {
	file, ok := reader.(*os.File)
	if !ok {
		return nil, fmt.Errorf("%w: prompt input must be a file, pipe, or terminal", os.ErrInvalid)
	}

	info, err := file.Stat()
	if err != nil {
		return nil, fmt.Errorf("stat input: %w", err)
	}

	// Regular files and /dev/null cannot be registered with epoll on Linux.
	null, _ := os.Stat(os.DevNull)
	if info.Mode().IsRegular() || (null != nil && os.SameFile(info, null)) {
		return &Input{scanner: bufio.NewScanner(file)}, nil
	}

	r, err := cancelreader.NewReader(file)
	if err != nil {
		return nil, fmt.Errorf("prepare input: %w", err)
	}

	return &Input{scanner: bufio.NewScanner(r), reader: r}, nil
}

// Close releases cancellation resources, leaving the input file open.
func (input *Input) Close() error {
	if input.reader != nil {
		if err := input.reader.Close(); err != nil {
			return fmt.Errorf("close input reader: %w", err)
		}
	}

	return nil
}

// ReadLine reads one line. Discard Input after cancellation.
func (input *Input) ReadLine(ctx context.Context) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", fmt.Errorf("read input: %w", err)
	}

	if input.reader != nil {
		done := make(chan struct{})
		stop := context.AfterFunc(ctx, func() {
			input.reader.Cancel()
			close(done)
		})

		defer func() {
			if !stop() {
				<-done
			}
		}()
	}

	ok := input.scanner.Scan()

	if err := ctx.Err(); err != nil {
		return "", fmt.Errorf("read input: %w", err)
	}

	if err := input.scanner.Err(); err != nil {
		return "", fmt.Errorf("read input: %w", err)
	}

	if !ok {
		return "", io.EOF
	}

	return input.scanner.Text(), nil
}
