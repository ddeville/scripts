package main

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

func TestDiscoveryKeepsItsSlotUntilPanesStart(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))

	const ssh = `#!/bin/sh
case " $* " in *" -oProxyCommand=false "*) ;; *) exit 1 ;; esac
mkdir slot 2>/dev/null || { echo "Session open refused by peer" >&2; exit 255; }
trap 'rmdir slot' EXIT
for arg do command=$arg; done
sh -c "$command"
`
	if err := os.WriteFile("ssh", []byte(ssh), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	dest := sshmux.Destination{Host: "devbox", Socket: filepath.Join(dir, "master")}

	if err := os.WriteFile("zmx", []byte("#!/bin/sh\necho 'name=term\tclients=0'\n"), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	m, err := openManagement(t.Context(), dest, dir)
	if err != nil {
		t.Fatal(err)
	}

	_, err = dest.Query(t.Context(), "true")

	m.close()

	if m.listing != "name=term\tclients=0\n\x00" {
		t.Fatalf("unexpected zmx listing %q", m.listing)
	}

	if !errors.Is(err, sshmux.ErrChannelRefused) {
		t.Fatalf("expected refusal while session held, got %v", err)
	}

	if _, err := dest.Query(t.Context(), "true"); err != nil {
		t.Fatalf("session not released: %v", err)
	}
}

func TestRestoreOnlyUnattachedSurvivors(t *testing.T) {
	t.Parallel()

	w := workspace{Host: "devbox", Path: "/work/api", Name: "api"}
	other := workspace{Host: "devbox", Path: "/personal/api", Name: "api"}
	moved := w.prefix() + "editor-AAAAAAAAAAAAA"
	first := w.prefix() + "shell-AAAAAAAAAAAAA"
	second := w.prefix() + "shell-BBBBBBBBBBBBB"
	names := map[string]bool{moved: true, second: true, first: true, other.prefix() + "repo-AAAAAAAAAAAAA": true}
	panes := map[string]tmux.Attachment{"%4": {Host: w.Host, Terminal: moved, Dead: true}}

	got, err := w.windows(names, panes, true)
	if err != nil {
		t.Fatal(err)
	}

	want := []window{{role: "shell", terminal: first}, {role: "shell", terminal: second}}
	if !slices.Equal(got, want) {
		t.Fatalf("restored windows = %v, want %v", got, want)
	}
}

func TestDiscoveryDistinguishesUnreachableFromGone(t *testing.T) {
	t.Parallel()

	const listing = "  name=term\terr=Timeout\tstatus=unreachable\n"

	names, err := inventory(listing + "\x00")
	if err != nil || !names["term"] {
		t.Fatalf("lost unresponsive terminal: %v, %v", names, err)
	}

	for _, out := range []string{"", listing, "unexpected output\x00"} {
		if _, err := inventory(out); err == nil {
			t.Errorf("accepted invalid inventory %q", out)
		}
	}
}

func TestRecoveryOnlyRetriesSSHFailuresOnThisDestination(t *testing.T) {
	t.Parallel()

	const terminal = "tm-1234567890abcdef1234.shell-AAAAAAAAAAAAA"

	panes := map[string]tmux.Attachment{
		"%1": {ID: "%1", Host: "dev", Terminal: terminal, Dead: true, ExitStatus: "255"},
		"%2": {ID: "%2", Host: "dev", Terminal: terminal, Dead: true, ExitStatus: "1"},
		"%3": {ID: "%3", Host: "dev", Terminal: terminal},
		"%4": {ID: "%4", Host: "other", Terminal: terminal, Dead: true, ExitStatus: "255"},
		"%5": {ID: "%5", Host: "dev", Dead: true, ExitStatus: "255"},
	}

	active, retry := interrupted(panes, "dev")
	if !active || !slices.Equal(retry, []tmux.Attachment{panes["%1"]}) {
		t.Fatalf("active = %t, retry = %v", active, retry)
	}

	if active, _ := interrupted(panes, "gone"); active {
		t.Fatal("supervisor should exit without panes")
	}
}

func TestRemoteExit255DoesNotTriggerReconnect(t *testing.T) {
	t.Parallel()

	cmd := exec.CommandContext(t.Context(), "sh", "-ec", "zmx() { return 255; }\n"+attach, "sh", "repo", "terminal", "/")
	if exit, ok := errors.AsType[*exec.ExitError](cmd.Run()); !ok || exit.ExitCode() != 1 {
		t.Fatalf("zmx exit 255 was not reported as a program failure: %v", cmd.ProcessState)
	}
}

func TestFailedPaneLookupKeepsReattachmentRetryable(t *testing.T) {
	t.Setenv("PATH", t.TempDir()) // tmux is unavailable before the helper can record a new connection.

	const terminal = "tm-1234567890abcdef1234.shell-AAAAAAAAAAAAA"
	for request, want := range map[string]int{terminal: 255, "shell": 1} {
		code, err := attachPane(t.Context(), request, "")
		if err == nil || code != want {
			t.Fatalf("attachPane(%s) = %d, %v, want status %d", request, code, err, want)
		}
	}
}

func TestWatcherSurvivesLookupFailureAndExitsWithServer(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("PATH", dir)

	const script = `#!/bin/sh
[ "$1" != -u ] || shift
if [ -f stopped ]; then
    echo "no server running on /test" >&2
    exit 1
fi
case "$1" in
list-panes)
    if [ ! -f failed ]; then
        : > failed
        exit 1
    fi
    printf '%%1\t@1\t0\tdev\ttm-1234567890abcdef1234.shell-AAAAAAAAAAAAA\t1\t\n'
    ;;
wait-for) : > stopped ;;
*) exit 1 ;;
esac
`
	if err := os.WriteFile("tmux", []byte(script), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	watch, err := lockFile(t.Context(), "watch")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = watch.Close() }()

	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()

	dest := sshmux.Destination{Host: "dev", Socket: filepath.Join(dir, "ssh")}
	if err := watchPanes(ctx, dest, watch); err != nil || ctx.Err() != nil {
		t.Fatalf("watchPanes = %v, context = %v", err, ctx.Err())
	}

	if _, err := os.Stat("stopped"); err != nil {
		t.Fatal("watcher did not resume waiting for pane events")
	}
}
