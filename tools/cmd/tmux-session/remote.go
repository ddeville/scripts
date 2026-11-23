package main

import (
	"cmp"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

type workspace struct {
	Host string `json:"host"`
	Path string `json:"path"`
	Name string `json:"name"`
}

func (w workspace) prefix() string {
	sum := sha256.Sum256([]byte(w.Host + "\x00" + w.Path + "\x00" + w.Name))
	return fmt.Sprintf("tm-%x.", sum[:10])
}

// tmux expands session names as formats, even when passed as separate arguments.
func displayName(s string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || strings.ContainsRune("@/_- ", r) {
			return r
		}

		return '_'
	}, s)
}

var (
	roles      = []string{"repo", "editor", "codex", "shell"}
	terminalID = regexp.MustCompile(`^tm-[0-9a-f]{20}\.(repo|editor|codex|shell)-[A-Z2-7]{13}$`)
)

type window struct {
	role, terminal string
}

const listTerminals = `zmx list
printf '\000'`

// The full listing also includes unresponsive sessions. --short hides those,
// so an outage could look like a fresh workspace or a successful close.
func inventory(out string) (map[string]bool, error) {
	list, ok := strings.CutSuffix(out, "\x00")
	if !ok {
		return nil, fmt.Errorf("%w: incomplete zmx listing", os.ErrInvalid)
	}

	names := make(map[string]bool)

	for line := range strings.Lines(list) {
		field, _, tab := strings.Cut(strings.TrimSpace(line), "\t")

		name, ok := strings.CutPrefix(field, "name=")
		if !tab || !ok || name == "" {
			return nil, fmt.Errorf("%w: unexpected zmx listing", os.ErrInvalid)
		}

		names[name] = true
	}

	return names, nil
}

const inspect = `unset CDPATH
command -v zmx >/dev/null || { echo 'Install zmx on the SSH host first' >&2; exit 1; }
cd -P -- "$HOME"
cd -P -- "$1"
printf '%s\000' "$PWD"
` + listTerminals

func openRemote(ctx context.Context, host, request, name string) (tmux.Session, bool, error) {
	if request == "" {
		return tmux.Session{}, false, fmt.Errorf("%w: empty remote path", os.ErrInvalid)
	}

	dest, err := sshDestination(host)
	if err != nil {
		return tmux.Session{}, false, err
	}

	lock, err := lockFile(dest.socket + ".lock")
	if err != nil {
		return tmux.Session{}, false, err
	}
	defer func() { _ = lock.Close() }()

	if err := dest.connect(ctx); err != nil {
		return tmux.Session{}, false, err
	}

	if request == "~" {
		request = "."
	}

	if !path.IsAbs(request) {
		request = "./" + strings.TrimPrefix(request, "~/")
	}

	out, err := dest.query(ctx, remoteCommand(inspect, request))
	if err != nil {
		return tmux.Session{}, false, err
	}

	dir, list, ok := strings.Cut(out, "\x00")
	if !ok || !path.IsAbs(dir) || !utf8.ValidString(dir) {
		return tmux.Session{}, false, fmt.Errorf("%w: invalid remote directory", os.ErrInvalid)
	}

	names, err := inventory(list)
	if err != nil {
		return tmux.Session{}, false, err
	}

	w := workspace{Host: host, Path: dir, Name: cmp.Or(name, path.Base(dir))}

	return w.open(ctx, names)
}

// Pane names and positions are mutable. Only a terminal ID can identify a
// survivor or show that it already has a pane, possibly in another session.
func (w workspace) windows(names map[string]bool, panes map[string]tmux.Attachment, fresh bool) ([]window, error) {
	prefix := w.prefix()
	attached := make(map[string]bool)

	for _, p := range panes {
		if p.Host == w.Host && strings.HasPrefix(p.Terminal, prefix) {
			attached[p.Terminal] = true
		}
	}

	var windows []window

	for id := range names {
		if !strings.HasPrefix(id, prefix) || attached[id] {
			continue
		}

		match := terminalID.FindStringSubmatch(id)
		if match == nil {
			return nil, fmt.Errorf("%w: invalid remote terminal ID", os.ErrInvalid)
		}

		windows = append(windows, window{role: match[1], terminal: id})
	}

	if fresh && len(windows) == 0 {
		if len(attached) != 0 {
			return []window{{role: "shell"}}, nil
		}

		return []window{{role: "repo"}, {role: "editor"}, {role: "codex"}}, nil
	}

	slices.SortFunc(windows, func(a, b window) int {
		return cmp.Or(cmp.Compare(slices.Index(roles, a.role), slices.Index(roles, b.role)), cmp.Compare(a.terminal, b.terminal))
	})

	return windows, nil
}

func (w workspace) open(ctx context.Context, names map[string]bool) (tmux.Session, bool, error) {
	helper, err := os.Executable()
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("locate tmux-session: %w", err)
	}

	meta, err := json.Marshal(w)
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("encode workspace: %w", err)
	}

	// SSH authentication and discovery must never hold the local project lock.
	lock, err := lockOpen()
	if err != nil {
		return tmux.Session{}, false, err
	}
	defer func() { _ = lock.Close() }()

	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("list sessions: %w", err)
	}

	var target tmux.Session

	for _, s := range sessions {
		if s.Remote == string(meta) {
			target = s
			break
		}
	}

	var panes map[string]tmux.Attachment
	if len(sessions) != 0 {
		panes, err = tmux.Attachments(ctx, "")
		if err != nil {
			return tmux.Session{}, false, fmt.Errorf("find existing remote panes: %w", err)
		}
	}

	created := target.ID == ""

	windows, err := w.windows(names, panes, created)
	if err != nil {
		return tmux.Session{}, false, err
	}

	// All workspaces on the destination lost the same connection.
	for _, p := range panes {
		if p.Host != w.Host || !p.Dead {
			continue
		}

		if err := p.Resume(ctx, helper, "--remote-pane", p.Terminal); err != nil {
			return tmux.Session{}, false, fmt.Errorf("resume pane %s: %w", p.ID, err)
		}
	}

	if created {
		target.Name = tmux.AvailableName(sessions, displayName(w.Host+"/"+w.Name))
		target.Remote = string(meta)
		first := windows[0]
		windows = windows[1:]

		target.ID, err = tmux.NewRemoteSession(ctx, target, first.role, "exec "+quote(helper)+" --remote-pane shell",
			helper, "--remote-pane", cmp.Or(first.terminal, first.role))
		if err != nil {
			return tmux.Session{}, false, fmt.Errorf("create remote session: %w", err)
		}
	}

	for _, win := range windows {
		err := tmux.StartWindow(ctx, target.ID, win.role, "", helper, "--remote-pane", cmp.Or(win.terminal, win.role))
		if err != nil {
			return tmux.Session{}, false, fmt.Errorf("create remote window: %w", err)
		}
	}

	target.Path = w.Path

	return target, created, nil
}
