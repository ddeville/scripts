package sshmux

import (
	"context"
	"errors"
	"fmt"
	"os"
	"syscall"
	"time"
)

// Lock serializes management and pane admission across all local tmux servers.
// Wait for proxies and already approved pane launches to release the slot.
func (d Destination) Lock(ctx context.Context) (*os.File, error) {
	request, err := lock(ctx, d.Socket+".lock", syscall.LOCK_EX)
	if err != nil {
		return nil, err
	}

	slot, err := lock(ctx, d.Socket+".slot", syscall.LOCK_EX)
	if err != nil {
		_ = request.Close()
		return nil, err
	}

	_ = slot.Close()

	return request, nil
}

// Hold keeps subsequent operations out after the caller releases Lock.
// All helpers in a batch can hold it until SSH acknowledges their channels.
func (d Destination) Hold(ctx context.Context) (*os.File, error) {
	return lock(ctx, d.Socket+".slot", syscall.LOCK_SH)
}

// ProxySlot lets an idle proxy detect a waiting caller and yield to it.
func (d Destination) ProxySlot(ctx context.Context) (*os.File, error) {
	request, err := d.Lock(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = request.Close() }()

	return d.Hold(ctx)
}

// Waiting reports whether another operation needs the management slot.
func (d Destination) Waiting() bool {
	f, err := os.Open(d.Socket + ".lock") // #nosec G304 -- Private destination lock.
	if err != nil {
		return true
	}
	defer func() { _ = f.Close() }()

	return syscall.Flock(int(f.Fd()), syscall.LOCK_SH|syscall.LOCK_NB) != nil
}

func lock(ctx context.Context, path string, mode int) (*os.File, error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600) // #nosec G304 -- Private destination lock.
	if err != nil {
		return nil, fmt.Errorf("open SSH lock: %w", err)
	}

	for ctx.Err() == nil {
		err := syscall.Flock(int(f.Fd()), mode|syscall.LOCK_NB)
		if err == nil {
			return f, nil
		}

		if !errors.Is(err, syscall.EWOULDBLOCK) {
			_ = f.Close()
			return nil, fmt.Errorf("lock SSH destination: %w", err)
		}

		select {
		case <-ctx.Done():
		case <-time.After(25 * time.Millisecond):
		}
	}

	_ = f.Close()

	return nil, fmt.Errorf("wait for SSH destination: %w", ctx.Err())
}
