package remote

import (
	"cmp"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"os"
	"slices"
	"strconv"
	"strings"
)

// The path and logical workspace name identify the project on the devbox,
// regardless of the SSH alias or local tmux session name.
func (w Workspace) terminalPrefix() string {
	hash := sha256.Sum256([]byte(w.Path + "\x00" + w.Name))
	return fmt.Sprintf("tm-%s-%x.", shortName(w.Name), hash[:8])
}

func shortName(s string) string {
	s = strings.Map(func(c rune) rune {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-' {
			return c
		}

		return '_'
	}, s)

	return s[:min(len(s), 10)]
}

type remoteWindow struct {
	title    string
	index    int
	terminal string
}

const windowFormat = "#{window_index}\t#{window_name}"

// zmx labels are whitespace-delimited. Encode the title so duplicate names,
// spaces, and punctuation round-trip independently of the attachment target.
func windowLabel(index, title string) string {
	return index + "." + base64.RawURLEncoding.EncodeToString([]byte(title))
}

func (w remoteWindow) command(helper string, workspace Workspace) []string {
	if w.terminal != "" {
		return []string{helper, "resume", w.terminal}
	}

	args := []string{helper, "attach", "--terminal", workspace.terminalPrefix() + w.title}
	if w.title != "repo" {
		args = append(args, "--"+w.title)
	}

	return args
}

// DiscoverWindows lists the surviving terminals before local session creation.
func (w Workspace) DiscoverWindows(ctx context.Context, dir string) ([]remoteWindow, error) {
	const discover = `set -eu
sessions=$(zmx list --short)
while IFS= read -r name; do
    case "$name" in "$1"*) ;; *) continue ;; esac
    label=$(zmx get "$name" tm_window) || {
        sessions=$(zmx list --short)
        if printf '%s\n' "$sessions" | grep -Fxq -- "$name"; then exit 1; fi
        continue
    }
    printf '%s\t%s\n' "$name" "$label"
done <<EOF
$sessions
EOF`

	cmd := ssh(ctx, dir, w.Host, muxOptions("-T"), shellCommand(discover, w.terminalPrefix()))
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("discover remote windows: %w", err)
	}

	var windows []remoteWindow

	for line := range strings.SplitSeq(strings.TrimSuffix(string(out), "\n"), "\n") {
		if line == "" {
			continue
		}

		terminal, label, _ := strings.Cut(line, "\t")
		order, encoded, ok := strings.Cut(label, ".")
		index, indexErr := strconv.Atoi(order)

		title, titleErr := base64.RawURLEncoding.DecodeString(encoded)
		if !ok || indexErr != nil || titleErr != nil {
			return nil, fmt.Errorf("%w: invalid window label for %s", os.ErrInvalid, terminal)
		}

		windows = append(windows, remoteWindow{title: string(title), index: index, terminal: terminal})
	}

	if len(windows) == 0 {
		return []remoteWindow{{title: "repo"}, {title: "editor"}, {title: "codex"}}, nil
	}

	slices.SortFunc(windows, func(a, b remoteWindow) int {
		return cmp.Or(cmp.Compare(a.index, b.index), cmp.Compare(a.terminal, b.terminal))
	})

	return windows, nil
}
