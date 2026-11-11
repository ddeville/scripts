package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

var (
	errDirty       = errors.New("worktree has local changes")
	errInvalidName = errors.New("worktree name must be a single directory name")
)

type createOptions struct {
	Directory string
	Name      string
	Base      string
}

func createWorktree(ctx context.Context, root string, options createOptions) (worktree, error) {
	if options.Name == "" || options.Name == "." || options.Name == ".." || filepath.Base(options.Name) != options.Name {
		return worktree{}, errInvalidName
	}

	source, main, err := git.Locate(ctx, options.Directory)
	if err != nil {
		return worktree{}, fmt.Errorf("locate repository: %w", err)
	}

	base := options.Base
	if base == "" {
		state, statusErr := git.Status(ctx, source)
		if statusErr != nil {
			return worktree{}, fmt.Errorf("check source worktree: %w", statusErr)
		}

		if state != "clean" {
			return worktree{}, fmt.Errorf("%w; pass --base HEAD to leave changes in the source checkout", errDirty)
		}

		base = "HEAD"
	}

	if _, err := git.ResolveCommit(ctx, source, base); err != nil {
		return worktree{}, fmt.Errorf("resolve base commit: %w", err)
	}

	path, err := filepath.Abs(filepath.Join(root, filepath.Base(main), options.Name))
	if err != nil {
		return worktree{}, fmt.Errorf("resolve worktree path: %w", err)
	}

	if _, err := os.Lstat(path); !errors.Is(err, os.ErrNotExist) {
		if err != nil {
			return worktree{}, fmt.Errorf("check worktree path: %w", err)
		}

		return worktree{}, fmt.Errorf("%w: %s", os.ErrExist, path)
	}

	branch := "damien/cw/" + options.Name
	if err := git.AddWorktree(ctx, source, path, branch, base); err != nil {
		return worktree{}, fmt.Errorf("add worktree: %w", err)
	}

	return inspect(ctx, path)
}

func resolveWorktree(ctx context.Context, root, directory, target string) (worktree, error) {
	if target == "" || target == "." {
		return inspect(ctx, directory)
	}

	items, err := discover(root)
	if err != nil {
		return worktree{}, err
	}

	_, main, _ := git.Locate(ctx, directory)

	var matches []worktree

	for _, item := range items {
		if target == item.Repo+"/"+item.Name {
			return item, nil
		}

		if target == item.Name {
			if main != "" && item.Repo == filepath.Base(main) {
				return item, nil
			}

			matches = append(matches, item)
		}
	}

	if len(matches) == 1 {
		return matches[0], nil
	}

	if len(matches) > 1 {
		return worktree{}, fmt.Errorf("%w: %s matches several repositories; use repo/name or a path", os.ErrInvalid, target)
	}

	path := target
	if !filepath.IsAbs(path) {
		path = filepath.Join(directory, path)
	}

	return inspect(ctx, path)
}

func inspect(ctx context.Context, path string) (worktree, error) {
	source, main, err := git.Locate(ctx, path)
	if err != nil {
		return worktree{}, fmt.Errorf("locate repository: %w", err)
	}

	if source == main {
		return worktree{}, fmt.Errorf("%w: %s is the main checkout", git.ErrNotLinkedWorktree, source)
	}

	branch, err := readBranch(source)
	if err != nil {
		return worktree{}, fmt.Errorf("%s: %w", source, err)
	}

	return worktree{Repo: filepath.Base(main), Name: filepath.Base(source), Path: source, Branch: branch}, nil
}

type removal struct {
	Worktree worktree
	Branch   string
	Sessions []tmux.Session
	main     string
}

func planRemoval(ctx context.Context, item worktree, keepBranch bool) (removal, error) {
	item, err := inspect(ctx, item.Path)
	if err != nil {
		return removal{}, err
	}

	state, err := git.Status(ctx, item.Path)
	if err != nil {
		return removal{}, fmt.Errorf("check worktree status: %w", err)
	}

	if state != "clean" {
		return removal{}, fmt.Errorf("%w: %s", errDirty, item.Path)
	}

	_, main, err := git.Locate(ctx, item.Path)
	if err != nil {
		return removal{}, fmt.Errorf("locate repository: %w", err)
	}

	plan := removal{Worktree: item, main: main}
	if !keepBranch {
		plan.Branch, err = git.CurrentBranch(ctx, item.Path)
		if err != nil {
			return removal{}, fmt.Errorf("read branch: %w", err)
		}

		if plan.Branch != "" {
			if err := git.CheckMerged(ctx, main, plan.Branch); err != nil {
				return removal{}, fmt.Errorf("%w; use --keep-branch to retain it", err)
			}
		}
	}

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return removal{}, fmt.Errorf("list sessions: %w", err)
	}

	for _, session := range sessions {
		if session.Path == item.Path {
			plan.Sessions = append(plan.Sessions, session)
		}
	}

	return plan, nil
}

func removeWorktree(ctx context.Context, plan removal) error {
	current, err := planRemoval(ctx, plan.Worktree, plan.Branch == "")
	if err != nil {
		return err
	}

	if current.Worktree.Branch != plan.Worktree.Branch || current.Branch != plan.Branch || !slices.Equal(current.Sessions, plan.Sessions) {
		return fmt.Errorf("%w: worktree branch or tmux sessions changed; run remove again", os.ErrInvalid)
	}

	if err := git.RemoveWorktree(ctx, current.main, current.Worktree.Path); err != nil {
		return fmt.Errorf("remove Git worktree: %w", err)
	}

	var cleanupErrors []error

	if current.Branch != "" {
		if err := git.DeleteBranch(ctx, current.main, current.Branch); err != nil {
			cleanupErrors = append(cleanupErrors, err)
		}
	}

	for _, session := range current.Sessions {
		if err := tmux.KillSession(ctx, session.ID); err != nil {
			cleanupErrors = append(cleanupErrors, err)
		}
	}

	return errors.Join(cleanupErrors...)
}
