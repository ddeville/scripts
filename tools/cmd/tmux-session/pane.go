package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

const attach = `export ZMX_NO_DETACH_KEY=1
# Reserve status 255 for lost or refused SSH sessions.
trap '[ "$?" != 255 ] || exit 1' EXIT
if [ "$1" = resume ]; then
    zmx get "$2" >/dev/null
    # If it exits between get and attach, zmx must never relaunch its program.
    set -- "$2" /bin/sh -c 'exit 1'
else
    cd -P -- "$3"
    case "$1" in
    editor) set -- "$2" sh -c "exec ${EDITOR:-nvim}" ;;
    codex) set -- "$2" codex ;;
    *) set -- "$2" ;;
    esac
fi
printf '\000'
zmx attach "$@"`

func attachPane(ctx context.Context, requested, reply string) (int, error) {
	var (
		ready func()
		conn  net.Conn
	)

	// A raw respawn may replay a command whose supervisor has already left.
	if reply != "" {
		conn, _ = (&net.Dialer{}).DialContext(ctx, "unix", reply)
		if conn != nil {
			defer func() { _ = conn.Close() }()

			ready = func() {
				_, _ = io.WriteString(conn, "+")
				_ = conn.Close()
			}
		}
	}

	status, err := runPane(ctx, requested, ready)
	if err != nil {
		if conn != nil {
			_, _ = io.WriteString(conn, err.Error())
		} else {
			_ = tmux.Notify(ctx, "tm: "+tui.CleanLine(err.Error()))
		}
	}

	return status, err
}

func runPane(ctx context.Context, requested string, ready func()) (int, error) {
	// Keep local setup failures retryable when reattaching an existing terminal.
	failure := 1
	if terminalID.MatchString(requested) {
		failure = 255
	}

	id := os.Getenv("TMUX_PANE")

	panes, err := tmux.Attachments(ctx, id)
	if err != nil {
		return failure, fmt.Errorf("find attachment: %w", err)
	}

	p, ok := panes[id]
	if !ok {
		return failure, fmt.Errorf("%w: expected a tmux pane", os.ErrInvalid)
	}

	mode, dir := "resume", ""

	if p.Terminal == "" {
		var w workspace
		if err := json.Unmarshal([]byte(os.Getenv(tmux.RemoteEnv)), &w); err != nil {
			return failure, fmt.Errorf("read remote workspace: %w", err)
		}

		p.Host, p.Terminal, dir = w.Host, requested, w.Path
		if slices.Contains(roles, requested) {
			mode = requested
			p.Terminal = w.prefix() + mode + "-" + rand.Text()[:13]
		} else if !strings.HasPrefix(p.Terminal, w.prefix()) {
			return failure, fmt.Errorf("%w: terminal belongs to another workspace", os.ErrInvalid)
		}
	}

	if !terminalID.MatchString(p.Terminal) {
		return failure, fmt.Errorf("%w: invalid terminal ID", os.ErrInvalid)
	}

	dest, err := sshmux.ForHost(p.Host)
	if err != nil {
		return failure, fmt.Errorf("find pane connection: %w", err)
	}

	sshCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	timer := time.AfterFunc(15*time.Second, cancel)
	defer timer.Stop()

	// Splits have no supervisor holding the management session for them.
	if ready == nil {
		lock, err := lockDestination(sshCtx, dest)
		if err != nil {
			return failure, err
		}

		m, err := openManagement(sshCtx, dest, "")
		if err != nil {
			_ = lock.Close()

			if dir != "" {
				_ = panes[id].CloseOnExit(ctx)
			}

			return failure, fmt.Errorf("reserve management slot: %w", err)
		}

		ready = sync.OnceFunc(func() { m.close(); _ = lock.Close() })
		defer ready()
	}

	project := ""
	if dir != "" {
		project = displayName(path.Base(dir))
	}

	// Record before launching. An ambiguous failure can only reattach here.
	if err := p.Record(sshCtx, project); err != nil {
		return failure, fmt.Errorf("record remote pane: %w", err)
	}

	var stderr bytes.Buffer

	output := &paneOutput{opened: func() { timer.Stop(); ready() }}
	cmd := exec.CommandContext(sshCtx, "ssh", dest.Channel("-tt", remoteCommand(attach, mode, p.Terminal, dir))...) // #nosec G204 -- Pinned master and quoted arguments.
	cmd.SysProcAttr = &syscall.SysProcAttr{Foreground: true}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, output, io.MultiWriter(os.Stderr, &stderr)
	cmd.WaitDelay = time.Second

	err = cmd.Run()
	if err == nil {
		return 0, nil
	}

	exit, ok := errors.AsType[*exec.ExitError](err)
	if !ok || sshCtx.Err() != nil {
		return failure, fmt.Errorf("run SSH pane: %w", err)
	}

	code := max(1, exit.ExitCode())
	if output.opened == nil {
		return code, nil
	}

	err = sshmux.CommandError(err, stderr.String())
	if errors.Is(err, sshmux.ErrChannelRefused) {
		if dir != "" {
			_ = p.CloseOnExit(ctx)
		}

		return code, fmt.Errorf("%w on %s (one MaxSessions slot is reserved for management)", sshmux.ErrChannelRefused, p.Host)
	}

	return code, fmt.Errorf("SSH %s: %w", p.Host, err)
}

type paneOutput struct{ opened func() }

func (w *paneOutput) Write(data []byte) (int, error) {
	if w.opened != nil && bytes.IndexByte(data, 0) >= 0 {
		w.opened()
		w.opened = nil
	}

	n, err := os.Stdout.Write(data)
	if err != nil {
		return n, fmt.Errorf("write terminal output: %w", err)
	}

	return n, nil
}

// A missing live terminal may still be starting. A missing dead one can be
// removed, including after a successful kill whose acknowledgement was lost.
const stop = `zmx kill "$1" >/dev/null || [ "$2" = true ]
` + listTerminals

func stopTerminal(ctx context.Context, p tmux.Attachment) error {
	if !terminalID.MatchString(p.Terminal) {
		return fmt.Errorf("%w: invalid terminal ID", os.ErrInvalid)
	}

	dest, err := sshmux.ForHost(p.Host)
	if err != nil {
		return fmt.Errorf("find pane connection: %w", err)
	}

	command := remoteCommand(stop, p.Terminal, strconv.FormatBool(p.Dead))

	lock, err := lockDestination(ctx, dest)
	if err != nil {
		return err
	}
	defer func() { _ = lock.Close() }()

	out, err := dest.Query(ctx, command)
	if err != nil {
		return fmt.Errorf("stop terminal: %w", err)
	}

	names, err := inventory(out)
	if err != nil {
		return err
	}

	if names[p.Terminal] {
		return fmt.Errorf("%w: terminal is still running", os.ErrInvalid)
	}

	return nil
}

func closePanes(ctx context.Context, target string) error {
	panes, err := tmux.Attachments(ctx, target)
	if err != nil {
		return fmt.Errorf("find close target: %w", err)
	}

	var local []tmux.Attachment

	remote := false

	for _, p := range panes {
		if p.ID != target && p.WindowID != target {
			continue
		}

		if p.Terminal != "" {
			if err := stopTerminal(ctx, p); err != nil {
				return fmt.Errorf("could not confirm remote close for %s: %w", p.ID, err)
			}

			remote = true
		}

		if p.Dead || p.Terminal == "" {
			local = append(local, p)
		}
	}

	if !remote {
		return fmt.Errorf("%w: no remote terminal at %s", os.ErrInvalid, target)
	}

	for _, p := range local {
		if err := p.KillPane(ctx); err != nil {
			return fmt.Errorf("close pane %s: %w", p.ID, err)
		}
	}

	return nil
}
