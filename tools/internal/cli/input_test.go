//nolint:testpackage // Observe the scanner's underlying read to detect abandoned goroutines.
package cli

import (
	"bufio"
	"context"
	"errors"
	"io"
	"os"
	"testing"
	"time"

	"github.com/muesli/cancelreader"
)

type observedReader struct {
	cancelreader.CancelReader

	started, finished chan struct{}
}

func (r *observedReader) Read(data []byte) (int, error) {
	close(r.started)
	defer close(r.finished)

	return r.CancelReader.Read(data) //nolint:wrapcheck // This observer must preserve the reader's result unchanged.
}

func TestInputCancellationStopsRead(t *testing.T) {
	t.Parallel()

	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() { _ = r.Close(); _ = w.Close() })

	input, err := NewInput(r)
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() { _ = input.Close() })

	// Observe the actual read, so abandoning a blocked goroutine cannot pass.
	reader := &observedReader{CancelReader: input.reader, started: make(chan struct{}), finished: make(chan struct{})}
	input.reader, input.scanner = reader, bufio.NewScanner(reader)
	ctx, cancel := context.WithCancel(t.Context())
	t.Cleanup(cancel)

	done := make(chan error, 1)

	go func() {
		_, err := input.ReadLine(ctx)
		done <- err
	}()

	<-reader.started
	cancel()

	select {
	case err := <-done:
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("ReadLine() = %v, want cancellation", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("cancellation did not unblock input")
	}

	select {
	case <-reader.finished:
	default:
		t.Fatal("ReadLine returned while the underlying read was still running")
	}

	if _, err := io.WriteString(w, "next\n"); err != nil {
		t.Fatal(err)
	}

	data := make([]byte, 5)
	if _, err := io.ReadFull(r, data); err != nil || string(data) != "next\n" {
		t.Fatalf("cancellation consumed or closed subsequent input: %q, %v", data, err)
	}
}

func TestInputBufferedLines(t *testing.T) {
	t.Parallel()

	for _, tc := range []struct {
		name         string
		cancelSecond bool
	}{
		{name: "multiple lines and EOF"},
		{name: "cancel buffered answer", cancelSecond: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			r, w, err := os.Pipe()
			if err != nil {
				t.Fatal(err)
			}

			t.Cleanup(func() { _ = r.Close(); _ = w.Close() })

			if _, err := io.WriteString(w, "first\nyes\n"); err != nil {
				t.Fatal(err)
			}

			if err := w.Close(); err != nil {
				t.Fatal(err)
			}

			input, err := NewInput(r)
			if err != nil {
				t.Fatal(err)
			}

			t.Cleanup(func() { _ = input.Close() })

			if line, err := input.ReadLine(t.Context()); err != nil || line != "first" {
				t.Fatalf("first line = %q, %v", line, err)
			}

			ctx, cancel := context.WithCancel(t.Context())
			defer cancel()

			if tc.cancelSecond {
				cancel()

				if line, err := input.ReadLine(ctx); line != "" || !errors.Is(err, context.Canceled) {
					t.Fatalf("accepted canceled confirmation: %q, %v", line, err)
				}

				return
			}

			if line, err := input.ReadLine(ctx); err != nil || line != "yes" {
				t.Fatalf("second line = %q, %v", line, err)
			}

			if _, err := input.ReadLine(ctx); !errors.Is(err, io.EOF) {
				t.Fatalf("end of input = %v, want EOF", err)
			}
		})
	}
}
