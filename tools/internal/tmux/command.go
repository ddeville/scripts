package tmux

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Programs need an attached client to query terminal colors and capabilities.
// The check and event subscription share a command queue so an attachment cannot
// fall between them. Event waiting requires tmux 3.8+ (wait-for -E).
func attachedCommand(command ...string) []string {
	const script = `
session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_id}') || exit
tmux if-shell -F -t "$TMUX_PANE" '#{==:#{session_attached},0}' \
  "wait-for -E -F '#{==:#{new_session},$session}' client-session-changed" || exit

if [ "$#" -eq 0 ]; then
  command=$(tmux show-options -Av -t "$TMUX_PANE" default-command) || exit
  [ -n "$command" ] && set -- "$command"
fi
case "$#" in
0) exec "$SHELL" -l ;;
1) exec "$SHELL" -c "$1" ;;
*) exec "$@" ;;
esac
`

	return append([]string{"/bin/sh", "-c", script, "sh"}, command...)
}

func run(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "tmux", args...) // #nosec G204 G702 -- Arguments are separate; callers explicitly supply any window shell command.
	cmd.WaitDelay = time.Second

	var stderr bytes.Buffer

	cmd.Stderr = &stderr

	output, err := cmd.Output()
	if err != nil {
		detail := strings.TrimSpace(string(output) + stderr.String())
		return detail, fmt.Errorf("tmux %s: %w: %s", args[0], err, detail)
	}

	return string(output), nil
}

func switchClient(ctx context.Context, target, client string) error {
	args := []string{"switch-client", "-t", target}
	if client != "" {
		args = append(args, "-c", client)
	}

	_, err := run(ctx, args...)

	return err
}
