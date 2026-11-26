//nolint:paralleltest // Fixtures isolate Git configuration and tmux through process environment variables.
package worktree_test

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/worktree"
)

func TestRemovalRechecksWorktree(t *testing.T) {
	for _, change := range []string{"none", "untracked file", "unmerged commit", "shared commit", "base moved", "force-delete unmerged branch"} {
		t.Run(change, func(t *testing.T) {
			main, path := removalFixture(t, false)

			forceBranch := change == "force-delete unmerged branch"
			if forceBranch {
				fixtureGit(t, path, "commit", "--allow-empty", "-m", "Unmerged work")
			}

			if change == "shared commit" || change == "base moved" {
				fixtureGit(t, path, "commit", "--allow-empty", "-m", "Shared commit")
				fixtureGit(t, main, "branch", "base", "topic")
			}

			plan, err := worktree.PlanRemovalWithBranchOptions(t.Context(), worktree.Info{Path: path}, false, forceBranch)
			if err != nil {
				t.Fatal(err)
			}

			var want error

			switch change {
			case "untracked file":
				if err := os.WriteFile(filepath.Join(path, "work.txt"), []byte("keep me"), 0o600); err != nil {
					t.Fatal(err)
				}

				want = worktree.ErrDirty
			case "unmerged commit":
				fixtureGit(t, path, "commit", "--allow-empty", "-m", "Unmerged work")

				want = git.ErrNotMerged
			case "base moved":
				fixtureGit(t, main, "branch", "-f", "base", "main")

				want = git.ErrNotMerged
			}

			commit := fixtureGit(t, path, "rev-parse", "HEAD")

			err = worktree.Remove(t.Context(), plan)
			if !errors.Is(err, want) {
				t.Fatalf("Remove() = %v, want %v", err, want)
			}

			_, statErr := os.Stat(path)
			if want == nil {
				if !errors.Is(statErr, os.ErrNotExist) {
					t.Fatalf("removed checkout still exists: %v", statErr)
				}

				if branches := fixtureGit(t, main, "branch", "--list", "topic"); branches != "" {
					t.Fatalf("removed branch still exists: %s", branches)
				}

				if change == "shared commit" {
					if got := fixtureGit(t, main, "rev-parse", "refs/heads/base"); got != commit {
						t.Fatalf("base = %s, want %s", got, commit)
					}
				}
			} else {
				if statErr != nil {
					t.Fatalf("refused removal lost the checkout: %v", statErr)
				}

				if got := fixtureGit(t, main, "rev-parse", "refs/heads/topic"); got != commit {
					t.Fatalf("refused removal changed the branch: got %s, want %s", got, commit)
				}

				if change == "untracked file" {
					data, err := os.ReadFile(filepath.Join(path, "work.txt")) // #nosec G304 -- Reads only this test's temporary worktree.
					if err != nil || string(data) != "keep me" {
						t.Fatalf("refused removal changed local work: %q, %v", data, err)
					}
				}
			}
		})
	}
}

func TestRemovalPreservesUnmergedDetachedCommit(t *testing.T) {
	_, path := removalFixture(t, true)

	plan, err := worktree.PlanRemoval(t.Context(), worktree.Info{Path: path}, false)
	if err != nil {
		t.Fatalf("merged detached checkout should be removable: %v", err)
	}

	fixtureGit(t, path, "commit", "--allow-empty", "-m", "Unmerged detached work")
	commit := fixtureGit(t, path, "rev-parse", "HEAD")

	for _, keepBranch := range []bool{false, true} {
		if _, err := worktree.PlanRemoval(t.Context(), worktree.Info{Path: path}, keepBranch); !errors.Is(err, worktree.ErrUnmergedDetached) {
			t.Fatalf("unmerged detached checkout (keep branch: %v): %v", keepBranch, err)
		}
	}

	if err := worktree.Remove(t.Context(), plan); !errors.Is(err, worktree.ErrUnmergedDetached) {
		t.Fatalf("removal using the earlier plan = %v, want refusal", err)
	}

	if got := fixtureGit(t, path, "rev-parse", "HEAD"); got != commit {
		t.Fatalf("refused removal changed detached HEAD: got %s, want %s", got, commit)
	}
}

func removalFixture(t *testing.T, detached bool) (string, string) {
	t.Helper()

	// Inherited Git overrides must never redirect fixture writes to another repo.
	for _, entry := range os.Environ() {
		name, _, _ := strings.Cut(entry, "=")
		if strings.HasPrefix(name, "GIT_") {
			t.Setenv(name, "") // Register restoration before removing the variable entirely.

			if err := os.Unsetenv(name); err != nil {
				t.Fatal(err)
			}
		}
	}

	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	t.Setenv("GIT_CONFIG_GLOBAL", os.DevNull)
	t.Setenv("GIT_AUTHOR_NAME", "Worktree test")
	t.Setenv("GIT_AUTHOR_EMAIL", "worktree@example.invalid")
	t.Setenv("GIT_COMMITTER_NAME", "Worktree test")
	t.Setenv("GIT_COMMITTER_EMAIL", "worktree@example.invalid")

	root := t.TempDir()

	bin := filepath.Join(root, "bin")
	if err := os.Mkdir(bin, 0o700); err != nil {
		t.Fatal(err)
	}

	// Only session discovery is expected; never operate on the user's tmux server.
	const tmuxFixture = `#!/bin/sh
[ "$1" = -u ] && [ "$2" = list-sessions ] || exit 99
printf '$1\tremote\t\tdevbox\t%s\n' "$FIXTURE_CHECKOUT"
`
	if err := os.WriteFile(filepath.Join(bin, "tmux"), []byte(tmuxFixture), 0o700); err != nil { // #nosec G306 -- Executable fixture in a private temporary directory.
		t.Fatal(err)
	}

	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	main, path := filepath.Join(root, "main"), filepath.Join(root, "checkout")
	t.Setenv("FIXTURE_CHECKOUT", path)
	fixtureGit(t, root, "init", "--template=", "--initial-branch=main", main)
	fixtureGit(t, main, "commit", "--allow-empty", "-m", "Initial commit")

	if detached {
		fixtureGit(t, main, "worktree", "add", "--detach", path, "HEAD")
	} else {
		fixtureGit(t, main, "worktree", "add", "-b", "topic", path)
	}

	return main, path
}

func fixtureGit(t *testing.T, path string, args ...string) string {
	t.Helper()
	cmd := exec.CommandContext(t.Context(), "git", append([]string{"-C", path}, args...)...) // #nosec G204 G702 -- Fixed test commands in temporary repositories; no shell evaluation.

	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}

	return strings.TrimSpace(string(output))
}
