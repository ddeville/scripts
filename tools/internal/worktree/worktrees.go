// Package worktree manages linked checkouts and their tmux/Codex sessions.
package worktree

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

// Info describes a managed checkout and its associated session.
type Info struct {
	Repo        string       `json:"repo"`
	Name        string       `json:"name"`
	Path        string       `json:"path"`
	Branch      string       `json:"branch"`
	Note        string       `json:"note,omitempty"`
	Status      string       `json:"status"`
	StatusError string       `json:"status_error,omitempty"`
	Session     tmux.Session `json:"session"`
}

// DefaultRoot honors GIT_SRC_WORKTREE_DIR or uses ~/src/worktrees.
func DefaultRoot() string {
	if root := os.Getenv("GIT_SRC_WORKTREE_DIR"); root != "" {
		return root
	}

	home, _ := os.UserHomeDir()

	return filepath.Join(home, "src/worktrees")
}

// Discover reads worktree metadata without waiting for Git or tmux.
func Discover(root string) ([]Info, error) {
	repos, err := os.ReadDir(root)
	if errors.Is(err, os.ErrNotExist) {
		return []Info{}, nil
	}

	if err != nil {
		return nil, fmt.Errorf("read worktree directory: %w", err)
	}

	result := []Info{}

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

			item, err := readCheckout(path)
			if err != nil {
				continue
			}

			item.Repo, item.Name, item.Status = repo.Name(), entry.Name(), "checking…"
			result = append(result, item)
		}
	}

	return result, nil
}

func readCheckout(path string) (Info, error) {
	metadata, err := git.OpenWorktreeMetadata(path)
	if err != nil {
		return Info{}, fmt.Errorf("inspect worktree: %w", err)
	}
	defer func() { _ = metadata.Close() }()

	head, err := git.ReadHEAD(metadata)
	if err != nil {
		return Info{}, fmt.Errorf("inspect worktree: %w", err)
	}

	item := Info{Path: canonical(path), Branch: head.Branch}
	if item.Branch == "" {
		item.Branch = "detached " + head.Commit[:min(8, len(head.Commit))]
	}

	item.Note = readNote(metadata)

	return item, nil
}

// List includes Git status and matching tmux sessions for all managed worktrees.
func List(ctx context.Context, root string) ([]Info, error) {
	items, err := Discover(root)
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
		items[i].Session = MatchSession(items[i], sessions)

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
