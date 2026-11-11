package git

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ErrNotLinkedWorktree means the path is not a linked Git checkout.
var ErrNotLinkedWorktree = errors.New("not a linked worktree")

// Head identifies the checked-out branch or detached commit.
type Head struct{ Branch, Commit string }

// ReadHEAD reads a linked worktree's metadata without launching Git.
func ReadHEAD(path string) (Head, error) {
	checkout, err := os.OpenRoot(path)
	if err != nil {
		return Head{}, fmt.Errorf("open worktree directory: %w", err)
	}
	defer func() { _ = checkout.Close() }()

	data, err := checkout.ReadFile(".git")
	if err != nil {
		return Head{}, fmt.Errorf("read worktree metadata: %w", err)
	}

	gitdir, ok := strings.CutPrefix(strings.TrimSpace(string(data)), "gitdir: ")
	if !ok {
		return Head{}, ErrNotLinkedWorktree
	}

	if !filepath.IsAbs(gitdir) {
		gitdir = filepath.Join(path, gitdir)
	}

	metadata, err := os.OpenRoot(gitdir)
	if err != nil {
		return Head{}, fmt.Errorf("open Git metadata directory: %w", err)
	}
	defer func() { _ = metadata.Close() }()

	if _, err := metadata.Stat("commondir"); err != nil {
		return Head{}, fmt.Errorf("read linked repository: %w", err)
	}

	data, err = metadata.ReadFile("HEAD")
	if err != nil {
		return Head{}, fmt.Errorf("read worktree HEAD: %w", err)
	}

	head := strings.TrimSpace(string(data))
	if branch, ok := strings.CutPrefix(head, "ref: refs/heads/"); ok {
		return Head{Branch: branch}, nil
	}

	return Head{Commit: head}, nil
}

// AddWorktree creates a linked checkout; an empty branch creates a detached HEAD.
func AddWorktree(ctx context.Context, repository, path, branch, base string) error {
	args := []string{"worktree", "add"}
	if branch == "" {
		args = append(args, "--detach")
	} else {
		if _, err := run(ctx, repository, "check-ref-format", "--branch", branch); err != nil {
			return err
		}

		args = append(args, "--no-track", "-b", branch)
	}

	_, err := run(ctx, repository, append(args, "--", path, base)...)

	return err
}

// RemoveWorktree removes a clean linked checkout using Git's safety checks.
func RemoveWorktree(ctx context.Context, repository, path string) error {
	_, err := run(ctx, repository, "worktree", "remove", "--", path)
	return err
}
