package sshmux_test

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
)

func TestAdmissionWaitsForEveryApprovedPane(t *testing.T) {
	t.Parallel()

	dest := sshmux.Destination{Host: "devbox", Socket: filepath.Join(t.TempDir(), "master")}
	lock, err := dest.Lock(t.Context())
	if err != nil {
		t.Fatal(err)
	}

	pane, err := dest.Hold(t.Context())
	if err != nil {
		t.Fatal(err)
	}

	// The caller goes away before the pane has finished opening its channel.
	_ = lock.Close()

	ctx, cancel := context.WithTimeout(t.Context(), 50*time.Millisecond)
	defer cancel()

	if _, err := dest.Lock(ctx); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("overlapped an approved launch: %v", err)
	}

	_ = pane.Close()

	lock, err = dest.Lock(t.Context())
	if err != nil {
		t.Fatal(err)
	}

	_ = lock.Close()
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

	dest := sshmux.Destination{Host: "devbox", Socket: filepath.Join(dir, "master")}

	err := dest.Connect(t.Context(), "/new-agent")
	if !errors.Is(err, sshmux.ErrSignIn) || !strings.Contains(err.Error(), "Host key verification failed") {
		t.Fatalf("expected an actionable host key failure that stops retries, got %v", err)
	}
}
