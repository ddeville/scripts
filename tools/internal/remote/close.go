package remote

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var (
	errStarting    = errors.New("remote pane is still starting")
	errUnconfirmed = errors.New("could not confirm remote close")
)

const closeScript = `if ! zmx kill "$1" >/dev/null 2>&1; then
    sessions=$(zmx list --short) || { echo failed; exit; }
    printf '%s\n' "$sessions" | grep -Fxq -- "$1" && { echo failed; exit; }
fi
rm -f -- "` + agentDirectory + `/$2"
echo closed`

// Close ends the matching remote terminals before removing their local panes.
func Close(ctx context.Context, target string, window bool) error {
	const format = "#{" + paneDirOption + "}\t#{" + terminalOption + "}"

	command := []string{"display-message", "-p", "-t", target, format}
	kill := "kill-pane"

	if window {
		command = []string{"list-panes", "-t", target, "-F", format}
		kill = "kill-window"
	}

	out, err := tmux.Run(ctx, append([]string{"-u"}, command...)...)
	if err != nil {
		return fmt.Errorf("read terminal targets: %w", err)
	}

	for line := range strings.SplitSeq(strings.TrimSuffix(out, "\n"), "\n") {
		dir, name, ok := strings.Cut(line, "\t")
		if !ok {
			return fmt.Errorf("%w: unexpected tmux pane metadata %q", os.ErrInvalid, line)
		}

		if dir == "" {
			continue
		}

		if name == "" {
			return fmt.Errorf("%w: %s", errStarting, target)
		}

		r, e := call(ctx, dir, request{Action: "close", Terminal: name})
		if e != nil || !r.Ready {
			return fmt.Errorf("%w for %s; retry after reconnecting", errUnconfirmed, target)
		}
	}

	detail, err := tmux.Run(ctx, kill, "-t", target)
	// zmx can finish the last process in a pane before we remove the tmux target.
	if err != nil && (strings.Contains(detail, "can't find pane:") || strings.Contains(detail, "can't find window:") || strings.Contains(detail, "no server running") || strings.Contains(detail, "No such file or directory")) {
		return nil
	}

	if err != nil {
		return fmt.Errorf("remove local target %s: %w", target, err)
	}

	return nil
}
