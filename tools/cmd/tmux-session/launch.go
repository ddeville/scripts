package main

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
)

var errPaneLimit = errors.New("SSH pane limit")

func capacityError(dest sshmux.Destination, want, free int) error {
	return fmt.Errorf("%s: %w (need %d, free %d, 1 reserved for management)", dest.Host, errPaneLimit, want, free)
}

// The local tmux server forks pane helpers asynchronously. Hold the destination
// lock until each helper confirms that its SSH session opened.
func launch(ctx context.Context, dest sshmux.Destination, count int, layout func(string) error) error {
	if count == 0 {
		return nil
	}

	token := rand.Text()[:16]
	socket := filepath.Join(filepath.Dir(dest.Socket), "open-"+token)

	listener, err := net.ListenUnix("unix", &net.UnixAddr{Net: "unix", Name: socket})
	if err != nil {
		return fmt.Errorf("listen for pane startup: %w", err)
	}
	defer func() { _ = listener.Close() }()

	if err := layout(token); err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	stop := context.AfterFunc(ctx, func() { _ = listener.Close() })
	defer stop()

	var panes []net.Conn

	for range count {
		conn, err := listener.Accept()
		if err != nil {
			return fmt.Errorf("wait for local panes: %w", err)
		}

		panes = append(panes, conn)
		defer func() { _ = conn.Close() }()
	}

	for _, conn := range panes {
		if _, err := conn.Write([]byte{'+'}); err != nil {
			return fmt.Errorf("start pane: %w", err)
		}
	}

	for _, conn := range panes {
		if err := ready(ctx, conn); err != nil {
			return fmt.Errorf("SSH pane did not start: %w", err)
		}
	}

	return nil
}

func ready(ctx context.Context, conn net.Conn) error {
	stop := context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer stop()

	var reply [1]byte
	if _, err := io.ReadFull(conn, reply[:]); err != nil {
		return fmt.Errorf("wait for startup: %w", err)
	}

	if reply[0] != '+' {
		return fmt.Errorf("%w: unexpected startup reply", os.ErrInvalid)
	}

	return nil
}

// A split or raw respawn has no supervisor waiting for it. Check capacity
// under the same lock, releasing it once SSH opens or the helper fails.
func admit(ctx context.Context, dest sshmux.Destination, token string) (func(bool), error) {
	if token != "" && token == filepath.Base(token) {
		socket := filepath.Join(filepath.Dir(dest.Socket), "open-"+token)

		hold, err := dest.Hold(ctx)
		if err != nil {
			return nil, fmt.Errorf("hold pane slot: %w", err)
		}

		conn, err := (&net.Dialer{}).DialContext(ctx, "unix", socket)
		if err != nil {
			_ = hold.Close()
			return nil, fmt.Errorf("contact pane supervisor: %w", err)
		}

		if err := ready(ctx, conn); err != nil {
			_ = hold.Close()
			_ = conn.Close()

			return nil, err
		}

		return func(open bool) {
			_ = hold.Close()

			if open {
				_, _ = conn.Write([]byte{'+'})
			}

			_ = conn.Close()
		}, nil
	}

	lock, err := dest.Lock(ctx)
	if err != nil {
		return nil, fmt.Errorf("lock destination: %w", err)
	}

	if err := requireCapacity(ctx, dest, 1); err != nil {
		_ = lock.Close()
		return nil, err
	}

	return func(bool) { _ = lock.Close() }, nil
}

func requireCapacity(ctx context.Context, dest sshmux.Destination, want int) error {
	free, err := dest.Capacity(ctx, want)
	if err != nil {
		return fmt.Errorf("check SSH capacity: %w", err)
	}

	if free < want {
		return capacityError(dest, want, free)
	}

	return nil
}
