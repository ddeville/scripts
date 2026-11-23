package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

// The foreground open owns interactive authentication. Hand off the lifetime
// lock on stdin so the supervisor survives the caller without a PID file.
func startSupervisor(ctx context.Context, dest sshmux.Destination) error {
	// Different local tmux servers share the master, but cannot see each
	// other's panes or events.
	socket, err := tmux.SocketPath(ctx)
	if err != nil {
		return fmt.Errorf("identify tmux server: %w", err)
	}

	server := sha256.Sum256([]byte(socket))
	filename := fmt.Sprintf("%s.%x.watch", dest.Socket, server[:8])

	lock, err := os.OpenFile(filename, os.O_RDWR|os.O_CREATE, 0o600) // #nosec G304 -- Private per-destination directory.
	if err != nil {
		return fmt.Errorf("open supervisor lock: %w", err)
	}

	defer func() { _ = lock.Close() }()

	err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
	if errors.Is(err, syscall.EWOULDBLOCK) {
		return nil
	}

	if err != nil {
		return fmt.Errorf("lock supervisor: %w", err)
	}

	helper, err := os.Executable()
	if err != nil {
		return fmt.Errorf("locate tmux-session: %w", err)
	}

	cmd := exec.CommandContext(context.WithoutCancel(ctx), helper, "--supervise", dest.Host) // #nosec G204 -- Re-exec this binary with a validated destination.
	cmd.Stdin = lock

	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start supervisor: %w", err)
	}

	go func() { _ = cmd.Wait() }()

	return nil
}

func supervise(ctx context.Context, host string) error {
	dest, err := sshmux.ForHost(host)
	if err != nil {
		return fmt.Errorf("find connection: %w", err)
	}

	helper, err := os.Executable()
	if err != nil {
		return fmt.Errorf("locate tmux-session: %w", err)
	}

	backoff := time.Second

	for ctx.Err() == nil {
		// Explicit opens and automatic retries must never start competing masters.
		lock, err := lockFile(dest.Socket + ".lock")
		if err != nil {
			return err
		}

		active, err := recoverPanes(ctx, dest, helper)

		done := !active || errors.Is(err, sshmux.ErrSignIn)
		if done {
			// Let a waiting interactive open start a new supervisor.
			_ = os.Stdin.Close()
		}

		_ = lock.Close()

		if done {
			return err
		}

		if err != nil {
			select {
			case <-ctx.Done():
				return nil
			case <-time.After(backoff):
			}

			backoff = min(backoff*2, 30*time.Second)

			continue
		}

		backoff = time.Second

		if err := tmux.WaitPaneDeath(ctx); err != nil {
			return fmt.Errorf("wait for failed panes: %w", err)
		}
	}

	return nil
}

func recoverPanes(ctx context.Context, dest sshmux.Destination, helper string) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	panes, err := tmux.Attachments(ctx, "")
	if err != nil {
		return false, fmt.Errorf("inspect remote panes: %w", err)
	}

	active, failed := interrupted(panes, dest.Host)

	if !active {
		// A new session exists before its panes finish recording their targets.
		sessions, err := tmux.ListSessions(ctx)
		if err != nil {
			return false, fmt.Errorf("look for remote sessions: %w", err)
		}

		for _, session := range sessions {
			var w workspace
			if session.Remote != "" && json.Unmarshal([]byte(session.Remote), &w) == nil && w.Host == dest.Host {
				return true, nil
			}
		}

		return false, nil
	}

	if len(failed) == 0 {
		return true, nil
	}

	connectErr := dest.Connect(ctx, false)
	if connectErr != nil && !errors.Is(connectErr, sshmux.ErrSignIn) {
		return true, fmt.Errorf("restore connection: %w", connectErr)
	}

	// Other clients may have exited or moved during the handshake.
	panes, err = tmux.Attachments(ctx, "")
	if err != nil {
		return false, fmt.Errorf("inspect remote panes: %w", err)
	}

	_, failed = interrupted(panes, dest.Host)
	if connectErr != nil {
		for _, p := range failed {
			_ = p.RequireSignIn(ctx)
		}

		return true, fmt.Errorf("restore connection: %w", connectErr)
	}

	generation := dest.Generation()
	if generation == "" {
		return true, fmt.Errorf("%w: missing SSH master", os.ErrNotExist)
	}

	for _, p := range failed {
		if p.Connection == generation {
			// A channel can fail independently, e.g. at MaxSessions.
			continue
		}

		if err := p.Resume(ctx, helper, "--remote-pane", p.Terminal); err != nil {
			return true, fmt.Errorf("resume pane %s: %w", p.ID, err)
		}
	}

	return true, nil
}

func interrupted(panes map[string]tmux.Attachment, host string) (bool, []tmux.Attachment) {
	active := false

	var failed []tmux.Attachment

	for _, p := range panes {
		if p.Host != host || !terminalID.MatchString(p.Terminal) {
			continue
		}

		active = true

		if p.Dead && p.ExitStatus == "255" {
			failed = append(failed, p)
		}
	}

	return active, failed
}
