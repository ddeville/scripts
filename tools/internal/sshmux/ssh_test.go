package sshmux_test

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ddeville/scripts/tools/internal/sshmux"
)

func TestSessionControlsWhichMasterPanesUse(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HOME", dir)
	t.Setenv("XDG_CACHE_HOME", dir)

	socket := func(host, session string) string {
		t.Helper()

		master, err := sshmux.ForSession(host, session)
		if err != nil {
			t.Fatal(err)
		}

		return master.Socket
	}

	first := socket("devbox", "a")
	if first != socket("devbox", "a") || first == socket("devbox", "b") || first == socket("other", "a") {
		t.Fatal("only panes of the same session and host should use the same master")
	}

	if _, err := sshmux.ForSession("devbox", ""); err == nil {
		t.Fatal("a missing session ID must not select a shared master")
	}
}

func TestConnectUsesCurrentAgentAndRefusesUntrustedHost(t *testing.T) {
	dir := t.TempDir()

	const ssh = `#!/bin/sh
case " $* " in *" -O check "*) exit 1 ;; esac
[ "$SSH_AUTH_SOCK" = /new-agent ] || exit 2
case " $* " in *" -oBatchMode=yes "*) ;; *) exit 3 ;; esac
case " $* " in *" -oStrictHostKeyChecking=yes "*) ;; *) exit 4 ;; esac
echo 'Host key verification failed.' >&2
exit 255
`
	if err := os.WriteFile(filepath.Join(dir, "ssh"), []byte(ssh), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	t.Setenv("PATH", dir)
	t.Setenv("SSH_AUTH_SOCK", "/old-agent")

	master := sshmux.Master{Host: "devbox", Socket: filepath.Join(dir, "master")}

	err := master.Connect(t.Context(), "/new-agent")
	if !errors.Is(err, sshmux.ErrSignIn) || !strings.Contains(err.Error(), "Host key verification failed") {
		t.Fatalf("expected an actionable host key failure that stops retries, got %v", err)
	}
}
