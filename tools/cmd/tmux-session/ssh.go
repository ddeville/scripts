package main

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"time"
)

type destination struct {
	host, socket string
}

var (
	sshHost           = regexp.MustCompile(`^[a-zA-Z0-9_@.%+:/\[\]-]+$`)
	errChannelRefused = errors.New("SSH session channel refused (check sshd MaxSessions)")
)

func sshDestination(host string) (destination, error) {
	if !sshHost.MatchString(host) || strings.HasPrefix(host, "-") {
		return destination{}, fmt.Errorf("%w: invalid SSH destination %q", os.ErrInvalid, host)
	}

	dir, err := cacheDir()
	if err != nil {
		return destination{}, err
	}

	info, err := os.Lstat(dir)
	if err != nil {
		return destination{}, fmt.Errorf("inspect SSH socket directory: %w", err)
	}

	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.IsDir() || int(stat.Uid) != os.Geteuid() || info.Mode().Perm()&0o077 != 0 {
		return destination{}, fmt.Errorf("%w: SSH socket directory %s must be private", os.ErrPermission, dir)
	}

	sum := sha256.Sum256([]byte(host))

	return destination{host: host, socket: filepath.Join(dir, fmt.Sprintf("ssh-%x", sum[:10]))}, nil
}

// Only tm opens a connection. OpenSSH retires the master after a minute with no open channels.
func (d destination) connect(ctx context.Context) error {
	if exec.CommandContext(ctx, "ssh", "-S", d.socket, "-O", "check", "--", d.host).Run() == nil { // #nosec G204 -- The validated destination follows --.
		return nil
	}

	cmd := exec.CommandContext(ctx, "ssh", "-S", d.socket, "-fN", "-oControlMaster=auto", "-oControlPersist=60", // #nosec G204 -- The validated destination follows --.
		"-oRemoteCommand=none", "-oConnectTimeout=10", "-oServerAliveInterval=5", "-oServerAliveCountMax=2", "--", d.host)
	cmd.Stdin, cmd.Stderr = os.Stdin, os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("connect to %s: %w", d.host, err)
	}

	return nil
}

// ControlMaster=no alone allows a direct connection if the socket is gone or the master refuses a channel.
func (d destination) channel(tty, command string) []string {
	return []string{
		"-S", d.socket, "-oControlMaster=no", "-oProxyCommand=false", "-oBatchMode=yes",
		"-oClearAllForwardings=yes", "-oRemoteCommand=none", "-oLogLevel=ERROR", "-e", "none", tty, "--", d.host, command,
	}
}

func (d destination) query(ctx context.Context, command string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "ssh", d.channel("-T", command)...) // #nosec G204 -- Fixed scripts with quoted arguments over the private master.
	cmd.WaitDelay = time.Second

	out, err := cmd.Output()
	if err != nil {
		var exit *exec.ExitError
		if errors.As(err, &exit) && len(exit.Stderr) != 0 {
			if exit.ExitCode() == 255 && strings.Contains(string(exit.Stderr), "Session open refused") {
				return "", fmt.Errorf("%w on %s", errChannelRefused, d.host)
			}

			return "", fmt.Errorf("SSH %s: %w: %s", d.host, err, strings.TrimSpace(string(exit.Stderr)))
		}

		return "", fmt.Errorf("SSH %s: %w", d.host, err)
	}

	return string(out), nil
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
