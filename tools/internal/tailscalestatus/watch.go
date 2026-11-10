package tailscalestatus

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"time"

	"tailscale.com/client/local"
	"tailscale.com/ipn"
)

var errWriteStatus = errors.New("write status")

// Run writes a snapshot, or watches the daemon and emits changed snapshots until canceled.
func Run(ctx context.Context, client *local.Client, output io.Writer, watch bool) error {
	var previous string

	write := func(data snapshot) error {
		encoded, err := json.Marshal(data)
		if err != nil {
			return fmt.Errorf("%w: %w", errWriteStatus, err)
		}

		line := string(encoded) + "\n"
		if line == previous {
			return nil
		}

		if _, err := io.WriteString(output, line); err != nil {
			return fmt.Errorf("%w: %w", errWriteStatus, err)
		}

		previous = line

		return nil
	}

	for {
		var err error

		if watch {
			err = stream(ctx, client, write)
		} else {
			var data snapshot

			data, err = collect(ctx, client)
			if err == nil {
				return write(data)
			}
		}

		if ctx.Err() != nil {
			return fmt.Errorf("read Tailscale: %w", ctx.Err())
		}

		if errors.Is(err, errWriteStatus) {
			return err
		}

		data := emptySnapshot()
		data.Error = err.Error()

		if err := write(data); err != nil {
			return err
		}

		if !watch {
			return nil
		}

		select {
		case <-ctx.Done():
			return fmt.Errorf("watch Tailscale: %w", ctx.Err())
		case <-time.After(2 * time.Second):
		}
	}
}

func stream(ctx context.Context, client *local.Client, write func(snapshot) error) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	// Bound subscription setup without putting a deadline on the long-lived stream.
	timer := time.AfterFunc(requestTimeout, cancel)
	watcher, err := client.WatchIPNBus(ctx, ipn.NotifyInitialState|ipn.NotifyPeerChanges)

	timer.Stop()

	if err != nil {
		return fmt.Errorf("subscribe to Tailscale: %w", err)
	}

	defer func() { _ = watcher.Close() }()

	for {
		if _, err := watcher.Next(); err != nil {
			return fmt.Errorf("watch Tailscale: %w", err)
		}

		data, err := collect(ctx, client)
		if err != nil {
			return err
		}

		if err := write(data); err != nil {
			return err
		}
	}
}
