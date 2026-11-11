package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/ddeville/scripts/tools/internal/git"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

type worktree struct {
	Repo        string       `json:"repo"`
	Name        string       `json:"name"`
	Path        string       `json:"path"`
	Branch      string       `json:"branch"`
	Status      string       `json:"status"`
	StatusError string       `json:"status_error,omitempty"`
	Session     tmux.Session `json:"session"`
}

func discover(root string) ([]worktree, error) {
	repos, err := os.ReadDir(root)
	if errors.Is(err, os.ErrNotExist) {
		return []worktree{}, nil
	}

	if err != nil {
		return nil, fmt.Errorf("read worktree directory: %w", err)
	}

	result := []worktree{}

	for _, repo := range repos {
		if !repo.IsDir() {
			continue
		}

		entries, err := os.ReadDir(filepath.Join(root, repo.Name()))
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", repo.Name(), err)
		}

		for _, entry := range entries {
			path := filepath.Join(root, repo.Name(), entry.Name())

			branch, err := readBranch(path)
			if err != nil {
				continue
			}

			result = append(result, worktree{
				Repo: repo.Name(), Name: entry.Name(), Path: canonical(path),
				Branch: branch, Status: "checking…",
			})
		}
	}

	return result, nil
}

func readBranch(path string) (string, error) {
	head, err := git.ReadHEAD(path)
	if err != nil {
		return "", fmt.Errorf("read worktree HEAD: %w", err)
	}

	if head.Branch != "" {
		return head.Branch, nil
	}

	return "detached " + head.Commit[:min(8, len(head.Commit))], nil
}

func listWorktrees(ctx context.Context, root string) ([]worktree, error) {
	items, err := discover(root)
	if err != nil {
		return nil, err
	}

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return nil, fmt.Errorf("list sessions: %w", err)
	}

	var workers sync.WaitGroup

	limit := make(chan struct{}, 4)

	for i := range items {
		items[i].Session = matchSession(items[i], sessions)

		workers.Go(func() {
			limit <- struct{}{}
			defer func() { <-limit }()

			state, statusErr := git.Status(ctx, items[i].Path)

			items[i].Status = state
			if statusErr != nil {
				items[i].StatusError = statusErr.Error()
			}
		})
	}

	workers.Wait()

	return items, nil
}

func canonical(path string) string {
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return filepath.Clean(resolved)
	}

	return filepath.Clean(path)
}
