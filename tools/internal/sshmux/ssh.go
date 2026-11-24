// Package sshmux shares a private OpenSSH master between tmux panes and agent queries.
package sshmux

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Destination identifies a master by its exact SSH destination.
type Destination struct {
	Host, Socket string
}

var (
	sshHost = regexp.MustCompile(`^[a-zA-Z0-9_@.%+:/\[\]-]+$`)
	// ErrChannelRefused indicates that the master cannot open another session.
	ErrChannelRefused = errors.New("SSH session channel refused (check sshd MaxSessions)")
	// ErrSignIn stops automatic retries until the user explicitly runs tm again.
	ErrSignIn = errors.New("SSH requires attention")
)

// ForHost resolves the private control socket without opening a connection.
func ForHost(host string) (Destination, error) {
	if !sshHost.MatchString(host) || strings.HasPrefix(host, "-") {
		return Destination{}, fmt.Errorf("%w: invalid SSH destination %q", os.ErrInvalid, host)
	}

	dir, err := CacheDir()
	if err != nil {
		return Destination{}, err
	}

	info, err := os.Lstat(dir)
	if err != nil {
		return Destination{}, fmt.Errorf("inspect SSH socket directory: %w", err)
	}

	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.IsDir() || int(stat.Uid) != os.Geteuid() || info.Mode().Perm()&0o077 != 0 {
		return Destination{}, fmt.Errorf("%w: SSH socket directory %s must be private", os.ErrPermission, dir)
	}

	sum := sha256.Sum256([]byte(host))

	return Destination{Host: host, Socket: filepath.Join(dir, fmt.Sprintf("ssh-%x", sum[:10]))}, nil
}

// Generation distinguishes old attachments from channels refused by a healthy
// master. OpenSSH creates a new socket for each connection.
func (d Destination) Generation() string {
	info, err := os.Stat(d.Socket)
	if err != nil {
		return ""
	}

	return strconv.FormatInt(info.ModTime().UnixNano(), 10)
}

// Connect starts or reuses the master under the destination lock. Let OpenSSH
// select the agent and identities from the caller's environment and config.
func (d Destination) Connect(ctx context.Context, agent string) error {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	if exec.CommandContext(ctx, "ssh", "-S", d.Socket, "-O", "check", "--", d.Host).Run() == nil { // #nosec G204 -- The validated destination follows --.
		return nil
	}

	cmd := exec.CommandContext(ctx, "ssh", // #nosec G204 -- The validated destination follows --.
		"-S", d.Socket, "-fN", "-oControlMaster=auto", "-oControlPersist=60",
		"-oRemoteCommand=none", "-oConnectTimeout=10", "-oServerAliveInterval=5", "-oServerAliveCountMax=2",
		"-oBatchMode=yes", "-oStrictHostKeyChecking=yes", "--", d.Host)
	if agent != os.Getenv("SSH_AUTH_SOCK") {
		cmd.Env = append(cmd.Environ(), "SSH_AUTH_SOCK="+agent)
	}

	// A proxy can keep stderr open after ssh backgrounds the master.
	cmd.WaitDelay = time.Second
	if _, err := cmd.Output(); err != nil && !errors.Is(err, exec.ErrWaitDelay) {
		if ctx.Err() != nil {
			return fmt.Errorf("connect to %s: %w", d.Host, ctx.Err())
		}

		var exit *exec.ExitError
		if errors.As(err, &exit) && len(exit.Stderr) != 0 {
			detail := strings.TrimSpace(string(exit.Stderr))
			if needsSignIn(detail) {
				err = ErrSignIn
			}

			return fmt.Errorf("connect to %s: %w: %s", d.Host, err, detail)
		}

		return fmt.Errorf("connect to %s: %w", d.Host, err)
	}

	return nil
}

func needsSignIn(message string) bool {
	return strings.Contains(message, "Permission denied") ||
		strings.Contains(message, "Host key verification failed") ||
		strings.Contains(message, "Too many authentication failures")
}

// Channel returns ssh arguments for an existing master only.
// ControlMaster=no alone allows a direct connection if the socket is gone or the master refuses a channel.
func (d Destination) Channel(tty, command string) []string {
	return []string{
		"-S", d.Socket, "-oControlMaster=no", "-oProxyCommand=false", "-oBatchMode=yes",
		"-oClearAllForwardings=yes", "-oRemoteCommand=none", "-oLogLevel=ERROR", "-e", "none", tty, "--", d.Host, command,
	}
}

// Query runs one non-interactive command with a deadline.
func (d Destination) Query(ctx context.Context, command string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "ssh", d.Channel("-T", command)...) // #nosec G204 -- Fixed scripts with quoted arguments over the private master.
	cmd.WaitDelay = time.Second

	out, err := cmd.Output()
	if err != nil {
		return "", d.commandError(err, "")
	}

	return string(out), nil
}

func (d Destination) commandError(err error, stderr string) error {
	if exit, ok := errors.AsType[*exec.ExitError](err); ok {
		if stderr == "" {
			stderr = string(exit.Stderr)
		}

		if exit.ExitCode() == 255 && strings.Contains(stderr, "Session open refused") {
			return fmt.Errorf("%w on %s", ErrChannelRefused, d.Host)
		}
	}

	if stderr != "" {
		return fmt.Errorf("SSH %s: %w: %s", d.Host, err, strings.TrimSpace(stderr))
	}

	return fmt.Errorf("SSH %s: %w", d.Host, err)
}

// CacheDir locates the user’s session cache.
func CacheDir() (string, error) {
	cache, err := os.UserCacheDir()
	if err != nil {
		return "", fmt.Errorf("locate cache directory: %w", err)
	}

	dir := filepath.Join(cache, "tmux-session")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", fmt.Errorf("create session cache: %w", err)
	}

	return dir, nil
}
