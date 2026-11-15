// Package git inspects repositories and manages linked worktrees through Git.
package git

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Locate returns the enclosing checkout and its repository's main worktree.
func Locate(ctx context.Context, directory string) (root, main string, err error) {
	root, err = run(ctx, directory, "rev-parse", "--show-toplevel")
	if err != nil {
		return "", "", err
	}

	output, err := run(ctx, root, "worktree", "list", "--porcelain", "-z")
	if err != nil {
		return "", "", err
	}

	first, _, _ := strings.Cut(output, "\x00")
	main = strings.TrimPrefix(first, "worktree ")

	return canonical(root), canonical(main), nil
}

// Status reports clean, dirty, or unknown, including non-ignored untracked files.
func Status(ctx context.Context, path string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	output, err := run(ctx, path, "status", "--porcelain=v1", "-z", "--untracked-files=normal")
	if err != nil {
		return "unknown", fmt.Errorf("read Git status: %w", err)
	}

	if output != "" {
		return "dirty", nil
	}

	return "clean", nil
}

// StatusShort returns Git's short status, including non-ignored untracked files.
func StatusShort(ctx context.Context, path string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	return run(ctx, path, "status", "--short", "--untracked-files=normal")
}

// ResolveCommit verifies a revision and returns its commit ID.
func ResolveCommit(ctx context.Context, path, ref string) (string, error) {
	return run(ctx, path, "rev-parse", "--verify", "--end-of-options", ref+"^{commit}")
}

// CurrentBranch returns the current branch, or an empty string for detached HEAD.
func CurrentBranch(ctx context.Context, path string) (string, error) {
	return run(ctx, path, "branch", "--show-current")
}

// ErrNotMerged means the branch cannot be deleted without losing unmerged commits.
var ErrNotMerged = errors.New("branch is not merged")

// CheckMerged checks that ref is reachable from base.
func CheckMerged(ctx context.Context, path, ref, base string) error {
	_, err := run(ctx, path, "merge-base", "--is-ancestor", ref, base)
	if exited(err, 1) {
		return fmt.Errorf("%w: %s", ErrNotMerged, strings.TrimPrefix(ref, "refs/heads/"))
	}

	return err
}

// BranchDeletionBase returns an alternate local base for branch -d when needed.
func BranchDeletionBase(ctx context.Context, path, branch string) (string, error) {
	ref := "refs/heads/" + branch

	upstream, err := run(ctx, path, "rev-parse", "--verify", "--end-of-options", branch+"@{upstream}")
	if err == nil {
		return "", CheckMerged(ctx, path, ref, upstream)
	}

	mergedErr := CheckMerged(ctx, path, ref, "HEAD")
	if !errors.Is(mergedErr, ErrNotMerged) {
		return "", mergedErr
	}

	// Git's -c option splits at the first '='.
	if strings.Contains(branch, "=") {
		return "", mergedErr
	}

	// Preserve an upstream configuration even when its ref is missing.
	_, err = run(ctx, path, "config", "--get", "branch."+branch+".merge")
	switch {
	case err == nil:
		return "", mergedErr
	case !exited(err, 1):
		return "", err
	}

	output, err := run(ctx, path, "for-each-ref", "--contains="+ref, "--format=%(refname)%09%(symref)", "refs/heads/")
	if err != nil {
		return "", err
	}

	for line := range strings.SplitSeq(output, "\n") {
		candidate, target, ok := strings.Cut(line, "\t")
		if ok && target == "" && candidate != ref {
			return candidate, nil
		}
	}

	return "", mergedErr
}

// DeleteBranch supplies an alternate upstream for this invocation only.
func DeleteBranch(ctx context.Context, path, branch, base string) error {
	args := []string{"branch", "-d", "--", branch}

	if base != "" {
		args = append([]string{"-c", "branch." + branch + ".remote=.", "-c", "branch." + branch + ".merge=" + base}, args...)
	}

	_, err := run(ctx, path, args...)

	return err
}

func exited(err error, code int) bool {
	var exitErr *exec.ExitError

	return errors.As(err, &exitErr) && exitErr.ExitCode() == code
}

func run(ctx context.Context, path string, args ...string) (string, error) {
	command := append([]string{"--no-optional-locks", "-C", path}, args...)
	cmd := exec.CommandContext(ctx, "git", command...) // #nosec G204 -- Git is fixed; subcommands and paths are separate arguments, never shell source.
	cmd.WaitDelay = time.Second

	var stderr bytes.Buffer

	cmd.Stderr = &stderr

	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git %s: %w: %s", args[0], err, strings.TrimSpace(stderr.String()))
	}

	return strings.TrimSuffix(string(output), "\n"), nil
}

func canonical(path string) string {
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return filepath.Clean(resolved)
	}

	return filepath.Clean(path)
}
