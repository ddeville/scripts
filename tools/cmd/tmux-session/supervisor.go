package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

// A single reply covers SSH, discovery, layout and watcher election. No tmux
// server needs to exist until the remote directory has been verified.
type openResult struct {
	Session tmux.Session `json:"session"`
	Created bool         `json:"created"`
	Warning string       `json:"warning,omitempty"`
	Error   string       `json:"error,omitempty"`
}

func openRemote(ctx context.Context, host, path, name string) (tmux.Session, bool, error) {
	if host == "" || path == "" {
		return tmux.Session{}, false, fmt.Errorf("%w: expected an SSH host and remote path", os.ErrInvalid)
	}

	helper, err := os.Executable()
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("locate tmux-session: %w", err)
	}

	request, err := json.Marshal(workspace{Path: path, Name: name})
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("encode workspace request: %w", err)
	}

	cmd := exec.CommandContext(context.WithoutCancel(ctx), helper, "--supervise="+host) // #nosec G204 -- Re-exec this binary. ForHost validates the destination before SSH.
	cmd.Stdin = bytes.NewReader(request)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	reply, err := cmd.StdoutPipe()
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("open supervisor pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return tmux.Session{}, false, fmt.Errorf("start supervisor: %w", err)
	}

	// Cancellation belongs to the caller until startup has completed.
	stop := context.AfterFunc(ctx, func() { _ = cmd.Process.Signal(syscall.SIGTERM) })

	var result openResult

	err = json.NewDecoder(reply).Decode(&result)

	stop()

	_ = reply.Close()

	go func() { _ = cmd.Wait() }()

	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("wait for supervisor: %w", err)
	}

	if result.Error != "" {
		return tmux.Session{}, false, errors.New(result.Error) //nolint:err113 // The child sends the original diagnostic.
	}

	if result.Warning != "" {
		message := "tm: " + tui.CleanLine(result.Warning)
		_, _ = fmt.Fprintln(os.Stderr, message)
		_ = tmux.Notify(ctx, message)
	}

	return result.Session, result.Created, nil
}

// Only one process watches a given server and destination. Other explicit
// opens can reuse the master or retry immediately during backoff.
func watchLock(ctx context.Context, dest sshmux.Destination) (*os.File, error) {
	socket, err := tmux.SocketPath(ctx)
	if err != nil {
		return nil, fmt.Errorf("identify tmux server: %w", err)
	}

	server := sha256.Sum256([]byte(socket))
	filename := fmt.Sprintf("%s.%x.watch", dest.Socket, server[:8])

	lock, err := os.OpenFile(filename, os.O_RDWR|os.O_CREATE, 0o600) // #nosec G304 -- Private per-destination directory.
	if err != nil {
		return nil, fmt.Errorf("open supervisor lock: %w", err)
	}

	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = lock.Close()
		return nil, fmt.Errorf("lock supervisor: %w", err)
	}

	return lock, nil
}

func supervise(ctx context.Context, host string) error {
	var result openResult

	dest, err := sshmux.ForHost(host)

	var watch *os.File
	if err == nil {
		watch, err = prepare(ctx, dest, &result)
	}

	if err != nil {
		result.Error = err.Error()
	}

	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		return fmt.Errorf("notify caller: %w", err)
	}

	if watch == nil {
		return nil
	}
	defer func() { _ = watch.Close() }()

	return watchPanes(ctx, dest, watch)
}

func prepare(ctx context.Context, dest sshmux.Destination, result *openResult) (*os.File, error) {
	var w workspace
	if err := json.NewDecoder(os.Stdin).Decode(&w); err != nil {
		return nil, fmt.Errorf("read workspace request: %w", err)
	}

	lock, err := lockDestination(ctx, dest)
	if err != nil {
		return nil, err
	}
	defer func() { _ = lock.Close() }()

	agent := os.Getenv("SSH_AUTH_SOCK")
	if err := dest.Connect(ctx, agent); err != nil {
		return nil, fmt.Errorf("SSH: %w", err)
	}

	*result, err = openWorkspace(ctx, dest, w.Path, w.Name)
	if err != nil {
		return nil, err
	}

	// A successful open refreshes the agent path for the next reconnect.
	if err := lock.Truncate(0); err != nil {
		return nil, fmt.Errorf("update SSH agent socket: %w", err)
	}

	if _, err := lock.WriteString(agent); err != nil {
		return nil, fmt.Errorf("save SSH agent socket: %w", err)
	}

	watch, err := watchLock(ctx, dest)
	if errors.Is(err, syscall.EWOULDBLOCK) {
		return nil, nil //nolint:nilnil // This open succeeded and another process owns the watcher.
	}

	return watch, err
}

func watchPanes(ctx context.Context, dest sshmux.Destination, watch *os.File) error {
	backoff := time.Second
	notified := false

	for ctx.Err() == nil {
		// Explicit opens and automatic retries must never start competing masters.
		lock, err := lockDestination(ctx, dest)
		if err != nil {
			return err
		}

		active, err := recoverPanes(ctx, dest, lock)

		done := (!active && err == nil) || errors.Is(err, sshmux.ErrSignIn)
		if done {
			// Let the next open take over before releasing the destination lock.
			_ = watch.Close()
		}

		_ = lock.Close()

		if done {
			return err
		}

		if err == nil {
			err = tmux.WaitPaneDeath(ctx)
		}

		if err != nil {
			if backoff >= 4*time.Second && !notified {
				notified = tmux.Notify(ctx, "tm: retrying recovery for "+dest.Host+" · "+tui.CleanLine(err.Error())) == nil
			}

			select {
			case <-ctx.Done():
				return nil
			case <-time.After(backoff):
			}

			backoff = min(backoff*2, 30*time.Second)

			continue
		}

		backoff = time.Second
		notified = false
	}

	return nil
}

func recoverPanes(ctx context.Context, dest sshmux.Destination, lock *os.File) (bool, error) {
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

	agent, err := io.ReadAll(lock)
	if err != nil {
		return true, fmt.Errorf("read SSH agent socket: %w", err)
	}

	connectErr := dest.Connect(ctx, string(agent))
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

	m, err := openManagement(ctx, dest, "")
	if err != nil {
		return true, fmt.Errorf("open management session: %w", err)
	}
	defer m.close()

	resume := make([]window, 0, len(failed))
	for _, p := range failed {
		resume = append(resume, window{role: p.ID, terminal: p.Terminal, pane: p})
	}

	_, err = startPanes(ctx, dest, nil, resume)

	return true, err
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
