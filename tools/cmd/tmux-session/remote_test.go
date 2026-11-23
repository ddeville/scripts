package main

import (
	"slices"
	"testing"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

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
