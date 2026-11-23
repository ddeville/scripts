package tmux

import (
	"context"
	"fmt"
	"os"
	"strings"
)

// RemoteEnv identifies a remote session and supplies the workspace to new panes.
const RemoteEnv = "TM_REMOTE_WORKSPACE"

// NewRemoteSession sets the command for future windows and splits in the same
// queue that creates the session. Its local working directory is the user's home.
func NewRemoteSession(ctx context.Context, s Session, window, defaultCommand string, command ...string) (string, error) {
	args := []string{
		"new-session", "-d", "-P", "-F", "#{session_id}", "-s", literalFormat(s.Name), "-c", "#{HOME}",
		"-e", literalArg(RemoteEnv + "=" + s.Remote), "-n", literalFormat(window),
	}
	args = appendCommand(args, command)
	args = append(args, ";", "set-option", "-t", "="+s.Name+":", "default-command", literalArg(defaultCommand))

	out, err := run(ctx, args...)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(out), nil
}

// Attachment identifies a local pane and the remote terminal it owns, if any.
type Attachment struct {
	ID, WindowID   string
	Host, Terminal string
	Dead           bool
	server         string
}

// Attachments returns each pane once, even if its window is linked to multiple
// sessions. A pane or window ID limits the lookup to that window.
func Attachments(ctx context.Context, target string) (map[string]Attachment, error) {
	const format = "#{pane_id}\t#{window_id}\t#{pane_dead}\t#{@tm_host}\t#{@tm_terminal}\t#{pid}"

	args := []string{"list-panes", "-F", format}
	if target == "" {
		args = append(args, "-a")
	} else {
		args = append(args, "-t", literalArg(target))
	}

	out, err := run(ctx, args...)
	if err != nil {
		return nil, fmt.Errorf("list pane attachments: %w", err)
	}

	panes := make(map[string]Attachment)

	for line := range strings.Lines(out) {
		fields := strings.Split(strings.TrimSuffix(line, "\n"), "\t")
		if len(fields) != 6 {
			return nil, fmt.Errorf("%w: invalid pane record", os.ErrInvalid)
		}

		p := Attachment{ID: fields[0], WindowID: fields[1], Dead: fields[2] == "1", Host: fields[3], Terminal: fields[4], server: fields[5]}
		panes[p.ID] = p
	}

	return panes, nil
}

// Record pins a terminal to this pane, even across moves and respawns.
func (p Attachment) Record(ctx context.Context, project string) error {
	const message = "#{?#{==:#{pane_dead_status},255},SSH disconnected · rerun tm for #{@tm_host},Remote terminal exited or unavailable}"

	_, err := run(ctx, "set-option", "-p", "-t", p.ID, "@tm_host", literalArg(p.Host), ";",
		"set-option", "-p", "-t", p.ID, "@tm_project", literalArg(project), ";",
		"set-option", "-p", "-t", p.ID, "@tm_terminal", literalArg(p.Terminal), ";",
		"set-option", "-p", "-t", p.ID, "remain-on-exit", "failed", ";",
		"set-option", "-p", "-t", p.ID, "remain-on-exit-format", message)

	return err
}

// Resume replaces a dead client and its input queue. A live pane is left alone.
func (p Attachment) Resume(ctx context.Context, command ...string) error {
	_, err := run(ctx, appendCommand([]string{"respawn-pane", "-t", p.ID}, command)...)
	return err
}

// Disconnect stops just the local client and keeps the failed pane for retry.
func (p Attachment) Disconnect(ctx context.Context) error {
	return p.change(ctx, "respawn-pane -k -t "+p.ID+" /bin/sh -c 'exit 255'")
}

// KillPane removes this pane from its local window.
func (p Attachment) KillPane(ctx context.Context) error {
	return p.change(ctx, "kill-pane -t "+p.ID)
}

// A window can change or the server can restart while a close is in flight.
func (p Attachment) change(ctx context.Context, command string) error {
	same := "#{==:#{pid}/#{window_id}/#{@tm_terminal}," + p.server + "/" + p.WindowID + "/" + p.Terminal + "}"

	out, err := run(ctx, "if-shell", "-F", "-t", p.ID, same, command, "display-message -p changed")
	if err != nil {
		return err
	}

	if out != "" {
		return fmt.Errorf("%w: pane %s changed during close", os.ErrInvalid, p.ID)
	}

	return nil
}
