package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
	"github.com/ddeville/scripts/tools/internal/tui"
)

const attach = `export ZMX_NO_DETACH_KEY=1
if [ "$1" = resume ]; then
    zmx get "$2" >/dev/null
    printf '\000'
    # If it exits between get and attach, zmx must never relaunch its program.
    exec zmx attach "$2" /bin/sh -c 'exit 1'
fi
cd -P -- "$3"
printf '\000'
case "$1" in
editor) exec zmx attach "$2" sh -c "exec ${EDITOR:-nvim}" ;;
codex) exec zmx attach "$2" codex ;;
*) exec zmx attach "$2" ;;
esac`

func attachPane(ctx context.Context, requested, batch string) (int, error) {
	// Until an existing terminal can be reattached, keep a setup failure
	// retryable on its original SSH generation.
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

	finish, err := admit(ctx, dest, batch)
	if batch != "" && dir == "" && (errors.Is(err, os.ErrNotExist) || errors.Is(err, syscall.ECONNREFUSED)) {
		// respawn-pane can replay the original command after a batch ends.
		finish, err = admit(ctx, dest, "")
	}

	if err != nil {
		if original := panes[id]; original.Terminal == "" && errors.Is(err, errPaneLimit) {
			_ = original.CloseOnExit(ctx)
		}

		_ = tmux.Notify(ctx, "tm: "+tui.CleanLine(err.Error()))

		return failure, err
	}

	defer finish(false)

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	timer := time.AfterFunc(15*time.Second, cancel)
	defer timer.Stop()

	// Record before launching. An ambiguous failure can only reattach here.
	p.Connection = dest.Generation()

	project := ""
	if dir != "" {
		project = displayName(path.Base(dir))
	}

	if err := p.Record(ctx, project); err != nil {
		return failure, fmt.Errorf("record remote pane: %w", err)
	}

	cmd := exec.CommandContext(ctx, "ssh", dest.Channel("-tt", remoteCommand(attach, mode, p.Terminal, dir))...) // #nosec G204 -- Pinned master and quoted arguments.
	cmd.SysProcAttr = &syscall.SysProcAttr{Foreground: true}
	cmd.Stdin, cmd.Stderr = os.Stdin, os.Stderr
	cmd.Stdout = &paneOutput{opened: func() { timer.Stop(); finish(true) }}
	cmd.WaitDelay = time.Second

	if err := cmd.Run(); err != nil {
		if exit, ok := errors.AsType[*exec.ExitError](err); ok {
			return max(1, exit.ExitCode()), nil
		}

		return 1, fmt.Errorf("run SSH pane: %w", err)
	}

	return 0, nil
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

func stopTerminal(ctx context.Context, p *tmux.Attachment) error {
	if !terminalID.MatchString(p.Terminal) {
		return fmt.Errorf("%w: invalid terminal ID", os.ErrInvalid)
	}

	dest, err := sshmux.ForHost(p.Host)
	if err != nil {
		return fmt.Errorf("find pane connection: %w", err)
	}

	command := remoteCommand(stop, p.Terminal, strconv.FormatBool(p.Dead))

	lock, err := dest.Lock(ctx)
	if err != nil {
		return fmt.Errorf("lock destination: %w", err)
	}
	defer func() { _ = lock.Close() }()

	out, err := dest.Query(ctx, command)
	if errors.Is(err, sshmux.ErrChannelRefused) && !p.Dead {
		// At MaxSessions, free this attachment's slot for the close command.
		if err := p.Disconnect(ctx); err != nil {
			return fmt.Errorf("disconnect pane: %w", err)
		}

		p.Dead = true
		out, err = dest.Query(ctx, command)
	}

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

	var live, dead, local []tmux.Attachment

	for _, p := range panes {
		if p.ID != target && p.WindowID != target {
			continue
		}

		switch {
		case p.Terminal == "":
			local = append(local, p)
		case p.Dead:
			dead = append(dead, p)
		default:
			live = append(live, p)
		}
	}

	if len(live)+len(dead) == 0 {
		return fmt.Errorf("%w: no remote terminal at %s", os.ErrInvalid, target)
	}

	// Live clients exit with zmx and can free channels for the remaining closes.
	for _, p := range append(live, dead...) {
		if err := stopTerminal(ctx, &p); err != nil {
			return fmt.Errorf("could not confirm remote close for %s: %w", p.ID, err)
		}

		if p.Dead {
			local = append(local, p)
		}
	}

	for _, p := range local {
		if err := p.KillPane(ctx); err != nil {
			return fmt.Errorf("close pane %s: %w", p.ID, err)
		}
	}

	return nil
}
