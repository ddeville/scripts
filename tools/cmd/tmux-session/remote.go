package main

import (
	"bufio"
	"bytes"
	"cmp"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/ddeville/scripts/tools/internal/sshmux"
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
	pane           tmux.Attachment
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

// SSH passes a single command string to the login shell. Quote backslashes outside
// single quotes so both fish and POSIX shells pass them through literally.
func quote(s string) string {
	return "'" + strings.NewReplacer("'", "'\\''", "\\", "'\\\\'").Replace(s) + "'"
}

func remoteCommand(script string, args ...string) string {
	// A login's XDG_RUNTIME_DIR can disappear when the connection drops.
	const setup = `set -eu
unset ZMX_SESSION ZMX_SESSION_PREFIX
export ZMX_DIR="${ZMX_DIR:-$HOME/.cache/tm-zmx}" ZMX_DIR_MODE=0700 ZMX_LOG_MODE=0600
`

	var command strings.Builder
	command.WriteString("exec sh -c " + quote(setup+script) + " sh")

	for _, arg := range args {
		command.WriteByte(' ')
		command.WriteString(quote(arg))
	}

	return command.String()
}

const inspect = `unset CDPATH
command -v zmx >/dev/null || { echo 'Install zmx on the SSH host first' >&2; exit 1; }
cd -P -- "$HOME"
cd -P -- "$1"
printf '%s\000' "$PWD"
` + listTerminals

type management struct {
	dir, listing string
	close        func()
}

// Keep discovery's session open until sshd accepts or refuses the panes.
// Splits and reconnects need the slot but have nothing to discover.
func openManagement(ctx context.Context, dest sshmux.Destination, request string) (management, error) {
	script := inspect
	if request == "" {
		script = `printf '\000\000'`
	}

	command := remoteCommand(script+"\nread -r done || :", request)
	cmd := exec.CommandContext(ctx, "ssh", dest.Channel("-T", command)...) // #nosec G204 -- Pinned master and quoted arguments.
	cmd.WaitDelay = time.Second

	var stderr bytes.Buffer

	cmd.Stderr = &stderr

	in, err := cmd.StdinPipe()
	if err != nil {
		return management{}, fmt.Errorf("open management stdin: %w", err)
	}

	out, err := cmd.StdoutPipe()
	if err != nil {
		_ = in.Close()
		return management{}, fmt.Errorf("open management stdout: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return management{}, fmt.Errorf("start management session: %w", err)
	}

	stop := context.AfterFunc(ctx, func() { _ = out.Close() })
	defer stop()

	reader := bufio.NewReader(out)

	var fields [2]string
	for i := range fields {
		fields[i], err = reader.ReadString(0)
		if err != nil {
			_ = in.Close()

			if waitErr := cmd.Wait(); waitErr != nil {
				return management{}, fmt.Errorf("%s: %w", dest.Host, sshmux.CommandError(waitErr, stderr.String()))
			}

			return management{}, fmt.Errorf("read management reply: %w", err)
		}
	}

	return management{
		dir: strings.TrimSuffix(fields[0], "\x00"), listing: fields[1],
		close: func() { _ = in.Close(); _ = cmd.Wait() },
	}, nil
}

func openWorkspace(ctx context.Context, dest sshmux.Destination, request, name string) (openResult, error) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if request == "~" {
		request = "."
	}

	if !path.IsAbs(request) {
		request = "./" + strings.TrimPrefix(request, "~/")
	}

	m, err := openManagement(ctx, dest, request)
	if err != nil {
		return openResult{}, fmt.Errorf("inspect workspace: %w", err)
	}
	defer m.close()

	if !path.IsAbs(m.dir) || !utf8.ValidString(m.dir) {
		return openResult{}, fmt.Errorf("%w: invalid remote directory", os.ErrInvalid)
	}

	names, err := inventory(m.listing)
	if err != nil {
		return openResult{}, err
	}

	w := workspace{Host: dest.Host, Path: m.dir, Name: cmp.Or(name, path.Base(m.dir))}

	return w.open(ctx, dest, names)
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

func (w workspace) open(ctx context.Context, dest sshmux.Destination, names map[string]bool) (openResult, error) {
	meta, err := json.Marshal(w)
	if err != nil {
		return openResult{}, fmt.Errorf("encode workspace: %w", err)
	}

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return openResult{}, fmt.Errorf("list sessions: %w", err)
	}

	target := tmux.Session{Name: displayName(w.Host + "/" + w.Name), Remote: string(meta)}

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
			return openResult{}, fmt.Errorf("find existing remote panes: %w", err)
		}
	}

	created := target.ID == ""

	windows, err := w.windows(names, panes, created)
	if err != nil {
		return openResult{}, err
	}

	prefix := w.prefix()
	for _, p := range panes {
		if p.Host == w.Host && p.Dead && strings.HasPrefix(p.Terminal, prefix) && names[p.Terminal] && terminalID.MatchString(p.Terminal) {
			windows = append(windows, window{role: p.ID, terminal: p.Terminal, pane: p})
		}
	}

	target.Path = w.Path
	result := openResult{Session: target, Created: created}

	started, err := startPanes(ctx, dest, &result.Session, windows)
	if err != nil {
		if created && started == 0 {
			return openResult{}, err
		}

		var missing []string
		for _, win := range windows[started:] {
			missing = append(missing, win.role)
		}

		result.Warning = fmt.Sprintf("could not open %s: %v", strings.Join(missing, ", "), err)
	}

	return result, nil
}

func createRemote(ctx context.Context, target *tmux.Session, role string, command ...string) error {
	// Only allocating a session name and starting tmux require the local lock.
	lock, err := lockOpen(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = lock.Close() }()

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return fmt.Errorf("list sessions: %w", err)
	}

	target.Name = tmux.AvailableName(sessions, target.Name)

	target.ID, err = tmux.NewRemoteSession(ctx, *target, role, "exec "+quote(command[0])+" --remote-pane shell", command...)
	if err != nil {
		return fmt.Errorf("create remote session: %w", err)
	}

	return nil
}
