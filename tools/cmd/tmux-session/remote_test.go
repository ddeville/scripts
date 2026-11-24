package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/ddeville/scripts/tools/internal/sshmux"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

func TestWorkspaceChecksAllPaneSlotsBeforeCreatingWindows(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))

	const ssh = `#!/bin/sh
case " $* " in *" -oProxyCommand=false "*) ;; *) exit 1 ;; esac
for arg do command=$arg; done
for slot in 1 2 3; do
    if mkdir "$slot" 2>/dev/null; then
        trap 'rmdir "$slot"' EXIT
        sh -c "$command"
        exit $?
    fi
done
echo 'Session open refused by peer' >&2
exit 255
`
	if err := os.WriteFile("ssh", []byte(ssh), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	dest := sshmux.Destination{Host: "devbox", Socket: filepath.Join(dir, "master")}

	const tm = `#!/bin/sh
[ "$1" != -u ] || shift
if [ "$1" = list-sessions ]; then exit 0; fi
echo "$1" > unexpected
exit 1
`
	if err := os.WriteFile("tmux", []byte(tm), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	// Three slots are free, but one is needed for discovery, close and status.
	w := workspace{Host: dest.Host, Path: "/project", Name: "project"}
	if _, _, err := w.open(t.Context(), dest, nil); !errors.Is(err, errPaneLimit) {
		t.Fatalf("expected refusal of a three-window workspace, got %v", err)
	}

	if command, err := os.ReadFile("unexpected"); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("tmux command before capacity check: %q, %v", command, err)
	}

	if err := requireCapacity(t.Context(), dest, 2); err != nil {
		t.Fatalf("refused batch did not release its probes: %v", err)
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
    printf '%%1\t@1\t0\tdev\ttm-1234567890abcdef1234.shell-AAAAAAAAAAAAA\t1\t\t1\n'
    ;;
wait-for) : > stopped ;;
*) exit 1 ;;
esac
`
	if err := os.WriteFile("tmux", []byte(script), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	watch, err := lockFile("watch")
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
