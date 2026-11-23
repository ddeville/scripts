// Package remote runs local tmux workspaces backed by SSH and zmx.
package remote

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var errSessionAddress = errors.New("tmux did not return a session and socket")

// Workspace records the SSH destination and the owning local tmux session.
type Workspace struct {
	Host    string `json:"host"`
	Request string `json:"request"`
	Path    string `json:"path"`
	Name    string `json:"name"`
	Server  string `json:"server"`
	Session string `json:"session"`
}

// Matches accepts either the original remote path or its resolved location.
func (w Workspace) Matches(host, dir, name string) bool {
	if name == "" {
		name = path.Base(w.Path)
	}

	return w.Host == host && w.Name == name && (w.Request == dir || w.Path == dir)
}

// Load reads the local workspace metadata.
func Load(dir string) (Workspace, error) {
	var w Workspace

	b, err := os.ReadFile(filepath.Join(dir, "workspace.json")) // #nosec G304 G703 -- Fixed metadata filename in the private workspace directory.
	if err == nil {
		err = json.Unmarshal(b, &w)
	}

	if err != nil {
		return w, fmt.Errorf("read workspace metadata: %w", err)
	}

	return w, nil
}

func quote(s string) string { return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'" }

func shellCommand(script string, args ...string) string {
	var command strings.Builder
	command.WriteString("sh -c " + quote(script) + " sh")

	for _, arg := range args {
		command.WriteByte(' ')
		command.WriteString(quote(arg))
	}

	return command.String()
}

func ssh(ctx context.Context, dir, host string, options []string, command ...string) *exec.Cmd {
	args := []string{"-S", filepath.Join(dir, "ssh")}
	args = append(args, options...)
	args = append(args, "--", host)

	return exec.CommandContext(ctx, "ssh", append(args, command...)...) // #nosec G204 G702 -- The destination follows -- and remote arguments are shell quoted.
}

func muxOptions(tty string) []string {
	return []string{tty, "-o", "ControlMaster=no", "-o", "ProxyCommand=false", "-o", "BatchMode=yes"}
}

func master(ctx context.Context, dir, host string, interactive bool) error {
	opts := []string{"-fMN", "-o", "ControlPersist=no", "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2"}
	if !interactive {
		opts = append(opts, "-o", "BatchMode=yes")
	}

	cmd := ssh(ctx, dir, host, opts)
	cmd.Stdin = os.Stdin

	log, err := os.OpenFile(filepath.Join(dir, "ssh.log"), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600) // #nosec G304 -- Fixed filename in the private workspace directory.
	if err != nil {
		return fmt.Errorf("open SSH log: %w", err)
	}
	defer func() { _ = log.Close() }()

	cmd.Stderr = log
	if err := cmd.Run(); err != nil {
		detail, _ := os.ReadFile(log.Name())
		return fmt.Errorf("connect to %s: %w: %s", host, err, strings.TrimSpace(string(detail)))
	}

	return nil
}

// Prepare opens a private master using the caller's SSH configuration and terminal.
func Prepare(ctx context.Context, host, request, name string) (string, Workspace, error) {
	w := Workspace{Host: host, Request: request, Name: name}

	dir, err := os.MkdirTemp("/tmp", "tm-remote-")
	if err != nil {
		return "", w, fmt.Errorf("create workspace directory: %w", err)
	}

	if err = master(ctx, dir, host, true); err != nil {
		removeRuntime(dir)
		return "", w, err
	}

	const resolve = `set -eu
command -v zmx >/dev/null || { echo "zmx is required on the SSH host" >&2; exit 1; }
zmx help 2>&1 | grep -q print-env || { echo "zmx with print-env support is required" >&2; exit 1; }
zmx help 2>&1 | grep -q -- '--labels' || { echo "zmx with session label support is required" >&2; exit 1; }
unset CDPATH
cd -- "$HOME" && cd -P -- "$1" && pwd -P`

	cmd := ssh(ctx, dir, host, muxOptions("-T"), shellCommand(resolve, request))
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if err != nil {
		Cleanup(ctx, dir, w)
		return "", w, fmt.Errorf("resolve remote directory: %w", err)
	}

	w.Path = strings.TrimSuffix(string(out), "\n")
	if !path.IsAbs(w.Path) {
		Cleanup(ctx, dir, w)
		return "", w, fmt.Errorf("%w: unexpected remote path %q", os.ErrInvalid, w.Path)
	}

	if w.Name == "" {
		w.Name = path.Base(w.Path)
	}

	return dir, w, nil
}

// Cleanup releases the private SSH master and the local runtime files.
func Cleanup(ctx context.Context, dir string, w Workspace) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
	defer cancel()

	_ = ssh(ctx, dir, w.Host, []string{"-O", "exit"}).Run()
	removeRuntime(dir)
}

func startManager(ctx context.Context, dir string) error {
	helper, err := exec.LookPath("tmux-remote")
	if err != nil {
		return fmt.Errorf("locate manager: %w", err)
	}

	cmd := exec.CommandContext(context.WithoutCancel(ctx), helper, "manage", dir) // #nosec G204 G702 -- The installed manager outlives the invoking tm process.

	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start manager: %w", err)
	}

	if err := cmd.Process.Release(); err != nil {
		return fmt.Errorf("release manager: %w", err)
	}

	return nil
}

// Create attaches local windows to the workspace's surviving remote terminals.
func Create(ctx context.Context, dir string, w Workspace, display string, windows []remoteWindow) (string, error) {
	helper, err := exec.LookPath("tmux-remote")
	if err != nil {
		return "", fmt.Errorf("locate pane helper: %w", err)
	}

	helper, err = filepath.Abs(helper)
	if err != nil {
		return "", fmt.Errorf("resolve helper path: %w", err)
	}

	first := windows[0]
	args := []string{"-u", "new-session", "-d", "-P", "-F", "#{session_id}\t#{socket_path}", "-s", display, "-n", first.title, "-e", "TM_REMOTE_DIR=" + dir}

	out, err := tmux.Run(ctx, append(args, first.command(helper, w)...)...)
	if err != nil {
		return "", fmt.Errorf("create local session: %w", err)
	}

	id, server, ok := strings.Cut(strings.TrimSuffix(out, "\n"), "\t")
	if !ok {
		return "", errSessionAddress
	}

	w.Session, w.Server = id, server

	ready := false
	defer func() {
		if !ready {
			_ = tmux.KillSession(context.WithoutCancel(ctx), id)
		}
	}()

	if err = tmux.SetOption(ctx, id, tmux.RemoteOption, dir); err != nil {
		return "", fmt.Errorf("identify remote session: %w", err)
	}

	if err = tmux.SetOption(ctx, id, "default-command", "exec "+quote(helper)+" attach"); err != nil {
		return "", fmt.Errorf("set remote launch command: %w", err)
	}

	for _, window := range windows[1:] {
		args = []string{"new-window", "-d", "-t", id + ":", "-n", window.title}
		if _, err = tmux.Run(ctx, append(args, window.command(helper, w)...)...); err != nil {
			return "", fmt.Errorf("create remote window: %w", err)
		}
	}

	b, err := json.Marshal(w)
	if err != nil {
		return "", fmt.Errorf("encode workspace: %w", err)
	}

	if err = os.WriteFile(filepath.Join(dir, "workspace.tmp"), b, 0o600); err != nil {
		return "", fmt.Errorf("write workspace: %w", err)
	}

	if err = os.Rename(filepath.Join(dir, "workspace.tmp"), filepath.Join(dir, "workspace.json")); err != nil {
		return "", fmt.Errorf("publish workspace: %w", err)
	}

	if err = startManager(ctx, dir); err != nil {
		return "", err
	}

	ready = true

	return id, nil
}

func removeRuntime(dir string) {
	for _, name := range []string{"workspace.json", "workspace.tmp", "ssh", "ssh.log", "manager", "owner", "connect"} {
		_ = os.Remove(filepath.Join(dir, name))
	}

	_ = os.Remove(dir)
}

// Reopen lets the invoking terminal handle interactive authentication when the
// manager's unattended attempt has been denied.
func Reopen(ctx context.Context, dir string) error {
	status, err := call(ctx, dir, request{Action: "status"})
	if err != nil {
		return startManager(ctx, dir)
	}

	if !strings.HasPrefix(status.Message, "Sign-in required") {
		return nil
	}

	w, err := Load(dir)
	if err != nil {
		return err
	}

	return ensureMaster(ctx, dir, w.Host, true)
}

func ensureMaster(ctx context.Context, dir, host string, interactive bool) error {
	lock, err := os.OpenFile(filepath.Join(dir, "connect"), os.O_CREATE|os.O_RDWR, 0o600) // #nosec G304 -- Fixed filename in the private workspace directory.
	if err != nil {
		return fmt.Errorf("lock SSH startup: %w", err)
	}
	defer func() { _ = lock.Close() }()

	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return fmt.Errorf("lock SSH startup: %w", err)
	}

	if ssh(ctx, dir, host, []string{"-O", "check"}).Run() == nil {
		return nil
	}

	_ = os.Remove(filepath.Join(dir, "ssh"))

	return master(ctx, dir, host, interactive)
}
