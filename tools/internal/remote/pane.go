package remote

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var errNotRemote = errors.New("attach requires a managed remote tmux pane")

const (
	terminalOption = "@tm_remote_terminal"
	paneDirOption  = "@tm_remote_dir"
	agentDirectory = "$HOME/.cache/tmux-remote/agents"
)

const attachScript = `set -eu
cd -- "$1"
name=$2
export TM_ATTACH_ID=$3
export ZMX_TRACK_ENV="${ZMX_TRACK_ENV:-DISPLAY,SSH_AUTH_SOCK,SSH_AGENT_PID,SSH_CONNECTION,WINDOWID,XAUTHORITY,KITTY_LISTEN_ON,KITTY_PID,KITTY_WINDOW_ID},TM_ATTACH_ID"
kind=$4
label=$5
agent_dir="` + agentDirectory + `"
agent="$agent_dir/$6"
shift 6
if [ "$kind" = resume ]; then
    sessions=$(zmx list --short)
    printf '%s\n' "$sessions" | grep -Fxq -- "$name" || exit 66
fi
if [ -S "${SSH_AUTH_SOCK:-}" ]; then
    (umask 077 && mkdir -p -- "$agent_dir")
    ln -s -- "$SSH_AUTH_SOCK" "$agent.$TM_ATTACH_ID"
    mv -f -- "$agent.$TM_ATTACH_ID" "$agent"
elif [ -L "$agent" ]; then
    rm -f -- "$agent"
fi
export SSH_AUTH_SOCK="$agent"
case "$kind" in
resume) exec zmx attach "$name" /bin/false ;;
editor) exec zmx attach --labels "$label" "$name" sh -c "exec ${EDITOR:-nvim}" ;;
codex) exec zmx attach --labels "$label" "$name" codex ;;
*) exec zmx attach --labels "$label" "$name" "$@" ;;
esac`

func delay(ctx context.Context, d time.Duration) bool {
	select {
	case <-ctx.Done():
		return false
	case <-time.After(d):
		return true
	}
}

func screen(host, message string) {
	_, _ = fmt.Fprintf(os.Stdout, "\x1b[?1049l\x1b[0m\x1b[?25h\x1b[2J\x1b[H%s · %s\r\n", host, message)
}

func gate(ctx context.Context, pane string, enabled bool) error {
	flag := "-d"
	if enabled {
		flag = "-e"
	}

	_, err := tmux.Run(ctx, "select-pane", flag, "-t", pane)
	if err != nil {
		return fmt.Errorf("change pane input mode: %w", err)
	}

	return nil
}

func offline(ctx context.Context, pane, host, message string) error {
	if err := gate(ctx, pane, false); err != nil {
		return err
	}

	mode, _ := tmux.Run(ctx, "display-message", "-p", "-t", pane, "#{pane_mode}")
	if strings.TrimSpace(mode) == "copy-mode" {
		_, _ = tmux.Run(ctx, "send-keys", "-t", pane, "-X", "cancel")
	}
	// Discard input which was already buffered by the tty before tmux locked it.
	if err := flushInput(); err != nil {
		return err
	}

	screen(host, message)

	return nil
}

// Attach runs in the pane's foreground for the lifetime of its remote terminal.
func Attach(ctx context.Context, kind, name string, args []string) error {
	dir, pane := os.Getenv("TM_REMOTE_DIR"), os.Getenv("TMUX_PANE")
	if dir == "" || pane == "" {
		return errNotRemote
	}
	// A pane can move between sessions before its remote terminal starts.
	if _, err := tmux.Run(ctx, "set-option", "-p", "-t", pane, paneDirOption, dir); err != nil {
		return fmt.Errorf("record pane workspace: %w", err)
	}
	// The session's first pane may start before the manager publishes its metadata.
	if err := gate(ctx, pane, false); err != nil {
		return err
	}

	if err := flushInput(); err != nil {
		return err
	}

	var (
		w   Workspace
		err error
	)
	for range 100 {
		w, err = Load(dir)
		if err == nil {
			break
		}

		if !errors.Is(err, os.ErrNotExist) || !delay(ctx, 100*time.Millisecond) {
			return err
		}
	}

	if err != nil {
		return err
	}

	window, err := tmux.Run(ctx, "-u", "display-message", "-p", "-t", pane, windowFormat)
	if err != nil {
		return fmt.Errorf("read window name: %w", err)
	}

	index, title, _ := strings.Cut(strings.TrimSuffix(window, "\n"), "\t")

	label := "tm_window=" + windowLabel(index, title)
	if name == "" {
		name = w.terminalPrefix() + shortName(title) + "-" + rand.Text()[:13]
	} else if !strings.HasPrefix(name, w.terminalPrefix()) {
		return fmt.Errorf("%w: terminal %q belongs to another workspace", os.ErrInvalid, name)
	}

	agent := agentFile(name)

	message := "Connecting…"
	screen(w.Host, message)

	started := kind == "resume"
	nextManager := time.Now().Add(3 * time.Second)

	for ctx.Err() == nil {
		state, e := call(ctx, dir, request{Action: "status"})
		if e != nil || !state.Online {
			text := state.Message
			if text == "" {
				text = "Disconnected · Reconnecting…"
			}

			if text != message {
				message = text
				screen(w.Host, message)
			}

			if e != nil && time.Now().After(nextManager) {
				_ = startManager(ctx, dir)
				nextManager = time.Now().Add(5 * time.Second)
			}

			delay(ctx, time.Second)

			continue
		}

		attempt := rand.Text()

		mode := kind
		if started {
			mode = "resume"
		}

		command := shellCommand(attachScript, append([]string{w.Path, name, attempt, mode, label, agent}, args...)...)
		cmd := ssh(ctx, dir, w.Host, muxOptions("-tt"), command)
		wasReady, detail, attachErr := runAttachment(ctx, cmd, dir, pane, name, attempt)
		started = started || wasReady

		if ctx.Err() != nil {
			return fmt.Errorf("stop attachment: %w", ctx.Err())
		}

		var exit *exec.ExitError
		if errors.As(attachErr, &exit) && exit.ExitCode() == 255 {
			message = "Disconnected · Reconnecting…"
			if strings.Contains(detail, "Session open refused") {
				message = "SSH session channel refused · Retrying…"
			}

			if err = offline(ctx, pane, w.Host, message); err != nil {
				return err
			}

			delay(ctx, time.Second)

			continue
		}

		if wasReady && attachErr == nil {
			return nil
		}

		message = "Remote terminal exited"
		if attachErr != nil && !started {
			message = "Remote command failed · check zmx and the command on " + w.Host
		}

		if err = offline(ctx, pane, w.Host, message); err != nil {
			return err
		}

		if err = markClosable(ctx, pane, name); err != nil {
			return err
		}

		<-ctx.Done()

		return fmt.Errorf("stop attachment: %w", ctx.Err())
	}

	return fmt.Errorf("stop attachment: %w", ctx.Err())
}

// Keep the socket path short enough for Unix sockets, independent of the title.
func agentFile(name string) string {
	hash := sha256.Sum256([]byte(name))
	return hex.EncodeToString(hash[:12])
}

// Publish the close target only once creation has been confirmed or the launch
// has exited. An absent session during startup could still be about to appear.
func markClosable(ctx context.Context, pane, name string) error {
	if _, err := tmux.Run(ctx, "set-option", "-p", "-t", pane, terminalOption, name); err != nil {
		return fmt.Errorf("record remote terminal: %w", err)
	}

	return nil
}

func runAttachment(ctx context.Context, cmd *exec.Cmd, dir, pane, name, attempt string) (bool, string, error) {
	var stderr strings.Builder

	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, &stderr
	if err := cmd.Start(); err != nil {
		return false, "", fmt.Errorf("start SSH attachment: %w", err)
	}

	var waitErr error

	done := make(chan struct{})

	go func() {
		waitErr = cmd.Wait()

		close(done)
	}()

	probe := time.NewTicker(200 * time.Millisecond)
	defer probe.Stop()

	ready := false

	for {
		select {
		case <-done:
			return ready, stderr.String(), waitErr
		case <-probe.C:
			result, _ := call(ctx, dir, request{Action: "ready", Terminal: name, Attempt: attempt})
			if !result.Ready {
				continue
			}

			err := markClosable(ctx, pane, name)
			if err == nil {
				err = gate(ctx, pane, true)
			}

			if err != nil {
				_ = cmd.Process.Kill()

				<-done

				return false, "", err
			}

			ready = true

			probe.Stop()
		}
	}
}
