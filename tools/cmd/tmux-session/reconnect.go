package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

// tmux runs this on pane-died. A dropped master can interrupt many panes at
// once. Elect one recovery job under the session lock, and release it under
// that same lock so a new failure during the last attempt is never missed.
func reconnect(ctx context.Context, master sshmux.Master) error {
	lock, err := lockMaster(ctx, master)
	if err != nil {
		return err
	}
	defer func() { _ = lock.Close() }()

	job, err := os.OpenFile(master.Socket+".retry", os.O_RDWR|os.O_CREATE, 0o600) // #nosec G304 -- Private SSH socket directory.
	if err != nil {
		return fmt.Errorf("open recovery lock: %w", err)
	}
	defer func() { _ = job.Close() }()

	if err := syscall.Flock(int(job.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil
		}

		return fmt.Errorf("lock recovery: %w", err)
	}

	for delay := time.Second; ; delay = min(delay*2, 30*time.Second) {
		err := recoverPanes(ctx, master, lock)
		if err == nil || errors.Is(err, sshmux.ErrSignIn) {
			_ = os.Remove(job.Name()) // Job locks are opened only while the session lock is held.
			return nil
		}

		_ = lock.Close()

		if delay == 4*time.Second {
			_ = tmux.Notify(ctx, "tm: retrying recovery for "+master.Host+" · "+tui.CleanLine(err.Error()))
		}

		select {
		case <-ctx.Done():
			return nil
		case <-time.After(delay):
		}

		lock, err = lockMaster(ctx, master)
		if err != nil {
			return err
		}
	}
}

func recoverPanes(ctx context.Context, master sshmux.Master, lock *os.File) error {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	panes, err := tmux.Attachments(ctx, "")
	if err != nil {
		return fmt.Errorf("inspect interrupted panes: %w", err)
	}

	if len(interrupted(panes, master)) == 0 {
		return nil
	}

	agent, err := io.ReadAll(lock)
	if err != nil {
		return fmt.Errorf("read SSH agent socket: %w", err)
	}

	connectErr := master.Connect(ctx, string(agent))
	if connectErr != nil && !errors.Is(connectErr, sshmux.ErrSignIn) {
		return fmt.Errorf("restore connection: %w", connectErr)
	}

	// Other panes may have moved or lost their connection during the login.
	panes, err = tmux.Attachments(ctx, "")
	if err != nil {
		return fmt.Errorf("inspect interrupted panes: %w", err)
	}

	failed := interrupted(panes, master)
	if connectErr != nil {
		for _, p := range failed {
			_ = p.RequireSignIn(ctx)
		}

		return fmt.Errorf("restore connection: %w", connectErr)
	}

	m, err := openManagement(ctx, master, "")
	if err != nil {
		return fmt.Errorf("open management session: %w", err)
	}
	defer m.close()

	resume := make([]window, 0, len(failed))
	for _, p := range failed {
		resume = append(resume, window{role: p.ID, terminal: p.Terminal, pane: p})
	}

	_, err = startPanes(ctx, master, nil, resume)

	return err
}

func interrupted(panes map[string]tmux.Attachment, master sshmux.Master) []tmux.Attachment {
	var failed []tmux.Attachment

	for _, p := range panes {
		if p.Dead && p.ExitStatus == "255" && !p.NeedsSignIn &&
			p.Connection == master.ID && p.Host == master.Host && terminalID.MatchString(p.Terminal) {
			failed = append(failed, p)
		}
	}

	return failed
}
