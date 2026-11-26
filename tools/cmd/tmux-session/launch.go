package main

import (
	"cmp"
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

// Give sshd the real requests in order, with the management slot occupied.
func startPanes(ctx context.Context, master sshmux.Master, target *tmux.Session, windows []window) (int, error) {
	if len(windows) == 0 {
		return 0, nil
	}

	helper, err := os.Executable()
	if err != nil {
		return 0, fmt.Errorf("locate tmux-session: %w", err)
	}

	for i, win := range windows {
		reply := filepath.Join(filepath.Dir(master.Socket), "open-"+rand.Text()[:16])
		if err := win.start(ctx, target, helper, reply); err != nil {
			return i, err
		}
	}

	return len(windows), nil
}

// tmux returns as soon as it forks the helper. Read its one-time startup
// result before proceeding or releasing the management session.
func (w window) start(ctx context.Context, target *tmux.Session, helper, reply string) error {
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Net: "unix", Name: reply})
	if err != nil {
		return fmt.Errorf("listen for pane startup: %w", err)
	}
	defer func() { _ = listener.Close() }()

	command := []string{helper, "--remote-pane", cmp.Or(w.terminal, w.role), "--pane-reply", reply}
	switch {
	case w.pane.ID != "":
		err = w.pane.Resume(ctx, command...)
	case target.ID == "":
		err = createRemote(ctx, target, w.role, command...)
	default:
		err = tmux.StartWindow(ctx, target.ID, w.role, "", command...)
	}

	if err != nil {
		return fmt.Errorf("start %s: %w", w.role, err)
	}

	stop := context.AfterFunc(ctx, func() { _ = listener.Close() })
	defer stop()

	conn, err := listener.Accept()
	if err != nil {
		return fmt.Errorf("wait for %s: %w", w.role, err)
	}
	defer func() { _ = conn.Close() }()

	stop = context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer stop()

	result, err := io.ReadAll(conn)
	if err != nil {
		return fmt.Errorf("read pane startup: %w", err)
	}

	switch string(result) {
	case "+":
		return nil
	case "":
		return fmt.Errorf("pane startup: %w", io.ErrUnexpectedEOF)
	default:
		return errors.New(string(result)) //nolint:err113 // The pane sends its startup error.
	}
}
