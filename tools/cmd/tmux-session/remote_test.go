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

	dest := sshmux.Master{Host: "devbox", Socket: filepath.Join(dir, "master")}

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

	w := workspace{Host: "devbox", Path: "/work/api", Name: "api", Request: "./api", Connection: "old"}
	other := workspace{Host: "devbox", Path: "/personal/api", Name: "api"}
	moved := w.prefix() + "editor-AAAAAAAAAAAAA"
	first := w.prefix() + "shell-AAAAAAAAAAAAA"
	second := w.prefix() + "shell-BBBBBBBBBBBBB"
	names := map[string]bool{moved: true, second: true, first: true, other.prefix() + "repo-AAAAAAAAAAAAA": true}
	panes := map[string]tmux.Attachment{"%4": {Host: w.Host, Terminal: moved, Dead: true}}

	// A replacement session may have a new master and a different path spelling.
	w.Connection, w.Request = "new", w.Path

	got, err := w.windows(names, panes, true)
	if err != nil {
		t.Fatal(err)
	}

	want := []window{{role: "shell", terminal: first}, {role: "shell", terminal: second}}
	if !slices.Equal(got, want) {
		t.Fatalf("restored windows = %v, want %v", got, want)
	}
}

func TestReopenSelectsTheSessionEvenAfterRename(t *testing.T) {
	t.Parallel()

	sessions := []tmux.Session{
		{ID: "$1", Name: "renamed", Remote: `{"host":"dev","path":"/work/api","name":"api","request":"./api","connection":"a"}`},
		{ID: "$2", Remote: `{"host":"dev","path":"/work/api","name":"scratch","request":"./api","connection":"b"}`},
		{ID: "$3", Remote: `{"host":"dev","path":"/other/api","name":"api","request":"./other/api","connection":"c"}`},
	}

	for _, tc := range []struct{ dir, name, connection string }{
		{"./api", "", "a"},
		{"/work/api", "api", "a"},
		{"./api", "scratch", "b"},
		{"./other/api", "", "c"},
	} {
		known := matchingSessions(sessions, "dev", tc.name)
		if s := discoverySession(t.Context(), known, tc.dir); s.info.Connection != tc.connection {
			t.Errorf("reopen %s %q selected %q, want %q", tc.dir, tc.name, s.info.Connection, tc.connection)
		}
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

func TestRecoveryOnlyRetriesSSHFailuresOnThisConnection(t *testing.T) {
	t.Parallel()

	const terminal = "tm-1234567890abcdef1234.shell-AAAAAAAAAAAAA"

	panes := map[string]tmux.Attachment{
		"%1": {ID: "%1", Host: "dev", Connection: "a", Terminal: terminal, Dead: true, ExitStatus: "255"},
		"%2": {ID: "%2", Host: "dev", Connection: "a", Terminal: terminal, Dead: true, ExitStatus: "1"},
		"%3": {ID: "%3", Host: "dev", Connection: "a", Terminal: terminal},
		"%4": {ID: "%4", Host: "dev", Connection: "b", Terminal: terminal, Dead: true, ExitStatus: "255"},
		"%5": {ID: "%5", Host: "dev", Connection: "a", Dead: true, ExitStatus: "255"},
		"%6": {ID: "%6", Host: "dev", Connection: "a", Terminal: terminal, Dead: true, ExitStatus: "255", NeedsSignIn: true},
	}

	retry := interrupted(panes, sshmux.Master{Host: "dev", ID: "a"})
	if !slices.Equal(retry, []tmux.Attachment{panes["%1"]}) {
		t.Fatalf("retry = %v", retry)
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

func TestReconnectRetriesLookupAndExitsWithServer(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("PATH", dir)

	const script = `#!/bin/sh
if [ -f failed ]; then
    : > stopped
    echo "no server running on /test" >&2
fi
: > failed
exit 1
`
	if err := os.WriteFile("tmux", []byte(script), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private test directory.
		t.Fatal(err)
	}

	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()

	dest := sshmux.Master{Host: "dev", ID: "abc", Socket: filepath.Join(dir, "ssh")}
	if err := reconnect(ctx, dest); err != nil || ctx.Err() != nil {
		t.Fatalf("reconnect = %v, context = %v", err, ctx.Err())
	}

	if _, err := os.Stat("stopped"); err != nil {
		t.Fatal("reconnect did not retry the failed lookup")
	}
}
