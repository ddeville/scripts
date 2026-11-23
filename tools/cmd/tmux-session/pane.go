package main

import (
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

	"github.com/ddeville/scripts/tools/internal/tmux"
)

const attach = `export ZMX_NO_DETACH_KEY=1
if [ "$1" = resume ]; then
    zmx get "$2" >/dev/null
    # If it exits between get and attach, zmx must never relaunch its program.
    exec zmx attach "$2" /bin/sh -c 'exit 1'
fi
cd -P -- "$3"
case "$1" in
editor) exec zmx attach "$2" sh -c "exec ${EDITOR:-nvim}" ;;
codex) exec zmx attach "$2" codex ;;
*) exec zmx attach "$2" ;;
esac`

func attachPane(ctx context.Context, requested string) error {
	id := os.Getenv("TMUX_PANE")

	panes, err := tmux.Attachments(ctx, id)
	if err != nil {
		return fmt.Errorf("find attachment: %w", err)
	}

	p, ok := panes[id]
	if !ok {
		return fmt.Errorf("%w: expected a tmux pane", os.ErrInvalid)
	}

	mode, dir := "resume", ""

	if p.Terminal == "" {
		var w workspace
		if err := json.Unmarshal([]byte(os.Getenv(tmux.RemoteEnv)), &w); err != nil {
			return fmt.Errorf("read remote workspace: %w", err)
		}

		p.Host, p.Terminal, dir = w.Host, requested, w.Path
		if slices.Contains(roles, requested) {
			mode = requested
			p.Terminal = w.prefix() + mode + "-" + rand.Text()[:13]
		} else if !strings.HasPrefix(p.Terminal, w.prefix()) {
			return fmt.Errorf("%w: terminal belongs to another workspace", os.ErrInvalid)
		}
	}

	if !terminalID.MatchString(p.Terminal) {
		return fmt.Errorf("%w: invalid terminal ID", os.ErrInvalid)
	}

	dest, err := sshDestination(p.Host)
	if err != nil {
		return err
	}

	if dir != "" {
		// Record the target before launching. Even a manual respawn after
		// an ambiguous SSH failure can now only reattach to this terminal.
		if err := p.Record(ctx, displayName(path.Base(dir))); err != nil {
			return fmt.Errorf("record remote pane: %w", err)
		}
	}

	ssh, err := exec.LookPath("ssh")
	if err != nil {
		return fmt.Errorf("find ssh: %w", err)
	}

	args := dest.channel("-tt", remoteCommand(attach, mode, p.Terminal, dir))

	return fmt.Errorf("start ssh: %w", syscall.Exec(ssh, append([]string{ssh}, args...), os.Environ())) // #nosec G204 -- Replace only with ssh and quote remote arguments.
}

// A missing live terminal may still be starting. A missing dead one can be
// removed, including after a successful kill whose acknowledgement was lost.
const stop = `zmx kill "$1" >/dev/null || [ "$2" = true ]
` + listTerminals

func stopTerminal(ctx context.Context, p *tmux.Attachment) error {
	if !terminalID.MatchString(p.Terminal) {
		return fmt.Errorf("%w: invalid terminal ID", os.ErrInvalid)
	}

	dest, err := sshDestination(p.Host)
	if err != nil {
		return err
	}

	command := remoteCommand(stop, p.Terminal, strconv.FormatBool(p.Dead))

	out, err := dest.query(ctx, command)
	if errors.Is(err, errChannelRefused) && !p.Dead {
		// At MaxSessions, free this attachment's slot for the close command.
		if err := p.Disconnect(ctx); err != nil {
			return fmt.Errorf("disconnect pane: %w", err)
		}

		p.Dead = true
		out, err = dest.query(ctx, command)
	}

	if err != nil {
		return err
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
