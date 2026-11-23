package remote

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var errControlReply = errors.New("unexpected control channel response")

var errChannelTimeout = errors.New("remote control channel timed out")

// The admin shell reserves one SSH session channel, so a full server can still
// acknowledge attachments and close terminals.
type admin struct {
	cmd    *exec.Cmd
	in     io.WriteCloser
	out    *bufio.Reader
	exited chan struct{}
}

func newAdmin(ctx context.Context, dir, host string) (*admin, error) {
	cmd := ssh(ctx, dir, host, muxOptions("-T"), "exec sh")

	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("open control input: %w", err)
	}

	out, err := cmd.StdoutPipe()
	if err != nil {
		_ = in.Close()
		return nil, fmt.Errorf("open control output: %w", err)
	}

	if err = cmd.Start(); err != nil {
		_ = in.Close()
		return nil, fmt.Errorf("start control channel: %w", err)
	}

	a := &admin{cmd: cmd, in: in, out: bufio.NewReader(out), exited: make(chan struct{})}
	go func() { _ = cmd.Wait(); close(a.exited) }()

	return a, nil
}

func (a *admin) query(script string) (string, error) {
	type result struct {
		line string
		err  error
	}

	done := make(chan result, 1)

	go func() {
		if _, err := fmt.Fprintln(a.in, script); err != nil {
			done <- result{err: err}
			return
		}

		line, err := a.out.ReadString('\n')
		done <- result{strings.TrimSuffix(line, "\n"), err}
	}()

	select {
	case r := <-done:
		return r.line, r.err
	case <-time.After(5 * time.Second):
		_ = a.cmd.Process.Kill()

		<-done

		return "", errChannelTimeout
	}
}

type (
	request struct {
		Action   string `json:"action"`
		Terminal string `json:"terminal,omitempty"`
		Attempt  string `json:"attempt,omitempty"`
	}
	reply struct {
		Online  bool   `json:"online"`
		Ready   bool   `json:"ready"`
		Message string `json:"message,omitempty"`
	}
)

type manager struct {
	mu      sync.Mutex
	admin   *admin
	message string
}

// Keep the last acknowledged window labels on the live zmx sessions so renames
// and moves survive the loss of the local tmux server.
func (m *manager) syncWindows(labels, acknowledged map[string]string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.admin == nil {
		return
	}

	for name, label := range labels {
		if acknowledged[name] == label {
			continue
		}

		response, err := m.admin.query("if zmx set " + quote(name) + " " + quote("tm_window="+label) + " >/dev/null 2>&1; then echo ok; else echo failed; fi")
		if err == nil && response == "ok" {
			acknowledged[name] = label
		}
	}

	for name := range acknowledged {
		if _, exists := labels[name]; !exists {
			delete(acknowledged, name)
		}
	}
}

func (m *manager) handle(conn net.Conn) {
	defer func() { _ = conn.Close() }()

	_ = conn.SetDeadline(time.Now().Add(8 * time.Second))

	var r request
	if json.NewDecoder(conn).Decode(&r) != nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	resp := reply{Online: m.admin != nil, Message: m.message}
	if m.admin != nil {
		var script string

		switch r.Action {
		case "ready":
			script = "printf '%s\\n' \"$(zmx print-env " + quote(r.Terminal) + " TM_ATTACH_ID 2>/dev/null)\""
		case "close":
			script = shellCommand(closeScript, r.Terminal, agentFile(r.Terminal))
		}

		if script != "" {
			line, err := m.admin.query(script)
			switch {
			case err != nil:
				resp = reply{Message: "Connection lost"}
			case r.Action == "ready":
				resp.Ready = line != "" && line == r.Attempt
			default:
				resp.Ready = line == "closed"
			}
		}
	}

	if err := json.NewEncoder(conn).Encode(resp); err != nil {
		return
	}
}

func call(ctx context.Context, dir string, r request) (reply, error) {
	c, err := (&net.Dialer{Timeout: time.Second}).DialContext(ctx, "unix", filepath.Join(dir, "manager")) // #nosec G704 -- Unix socket inside the private workspace directory.
	if err != nil {
		return reply{}, fmt.Errorf("connect to workspace manager: %w", err)
	}
	defer func() { _ = c.Close() }()

	_ = c.SetDeadline(time.Now().Add(8 * time.Second))
	if err = json.NewEncoder(c).Encode(r); err != nil {
		return reply{}, fmt.Errorf("send manager request: %w", err)
	}

	var resp reply

	err = json.NewDecoder(c).Decode(&resp)
	if err != nil {
		return resp, fmt.Errorf("read manager response: %w", err)
	}

	return resp, nil
}

// Manage keeps the transport alive while the workspace or any of its panes exists.
func Manage(ctx context.Context, dir string) error {
	w, err := Load(dir)
	if err != nil {
		return err
	}

	lock, err := os.OpenFile(filepath.Join(dir, "owner"), os.O_CREATE|os.O_RDWR, 0o600) // #nosec G304 -- Fixed filename in the private workspace directory.
	if err != nil {
		return fmt.Errorf("open manager lock: %w", err)
	}
	defer func() { _ = lock.Close() }()

	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil
		}

		return fmt.Errorf("lock workspace manager: %w", err)
	}

	endpoint := filepath.Join(dir, "manager")
	_ = os.Remove(endpoint)

	l, err := new(net.ListenConfig).Listen(ctx, "unix", endpoint)
	if err != nil {
		return fmt.Errorf("listen on manager socket: %w", err)
	}
	defer func() { _ = l.Close() }()

	m := &manager{message: "Connecting"}

	go func() {
		for {
			c, e := l.Accept()
			if e != nil {
				return
			}

			go m.handle(c)
		}
	}()

	tick := time.NewTicker(time.Second)
	defer tick.Stop()

	nextTry := time.Time{}
	acknowledged := make(map[string]string)

	for {
		const format = "#{" + tmux.RemoteOption + "}\t#{" + paneDirOption + "}\t#{" + terminalOption + "}\t" + windowFormat

		panes, e := tmux.RunOnSocket(ctx, w.Server, "-u", "list-panes", "-a", "-F", format)
		if ctx.Err() != nil {
			return fmt.Errorf("stop workspace manager: %w", ctx.Err())
		}

		if e != nil && !strings.Contains(panes, "no server running") && !strings.Contains(panes, "No such file or directory") && !strings.Contains(panes, "Connection refused") {
			// A failed inventory cannot establish that the workspace was closed.
			delay(ctx, time.Second)
			continue
		}

		labels := make(map[string]string)
		owned := false

		for line := range strings.SplitSeq(strings.TrimSuffix(panes, "\n"), "\n") {
			fields := strings.SplitN(line, "\t", 5)
			if len(fields) != 5 {
				continue
			}

			owned = owned || fields[0] == dir || fields[1] == dir
			if fields[1] == dir && strings.HasPrefix(fields[2], w.terminalPrefix()) {
				labels[fields[2]] = windowLabel(fields[3], fields[4])
			}
		}

		if e != nil || !owned {
			Cleanup(ctx, dir, w)
			return nil
		}

		m.syncWindows(labels, acknowledged)

		m.mu.Lock()
		if m.admin != nil {
			select {
			case <-m.admin.exited:
				m.admin = nil
				m.message = "Disconnected · Reconnecting…"
			default:
			}
		}

		connect := m.admin == nil && time.Now().After(nextTry)
		m.mu.Unlock()

		if connect {
			var a *admin

			e = ensureMaster(ctx, dir, w.Host, false)
			if e == nil {
				a, e = newAdmin(ctx, dir, w.Host)
			}

			if e == nil {
				var hello string

				hello, e = a.query("echo ready")
				if e == nil && hello != "ready" {
					e = errControlReply
				}
			}

			m.mu.Lock()
			if e != nil {
				if a != nil {
					_ = a.cmd.Process.Kill()
				}

				m.message = "Disconnected · Reconnecting…"
				if strings.Contains(e.Error(), "Permission denied") {
					m.message = "Sign-in required · reopen this workspace with tm"
				}
			} else {
				m.admin = a
				m.message = ""
			}
			m.mu.Unlock()

			nextTry = time.Now().Add(2 * time.Second)
		}

		select {
		case <-ctx.Done():
			return fmt.Errorf("stop workspace manager: %w", ctx.Err())
		case <-tick.C:
		}
	}
}
