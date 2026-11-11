package worktree

import (
	"context"
	"fmt"
)

// Create makes a managed checkout and its repo/editor/Codex session unless NoTmux is set.
// The checkout is returned even when subsequent session setup fails.
func Create(ctx context.Context, root string, options CreateOptions) (Info, string, error) {
	if !options.NoTmux {
		if err := checkSessionTools(); err != nil {
			return Info{}, "", fmt.Errorf("check session tools: %w", err)
		}
	}

	item, err := createWorktree(ctx, root, options)
	if err != nil {
		return item, "", fmt.Errorf("create worktree: %w", err)
	}

	if options.NoTmux {
		return item, "", nil
	}

	id, err := ensureSession(ctx, item, sessionOptions{Fork: options.Fork, ForkPicker: true, SourceDir: options.Directory})
	if err != nil {
		return item, "", fmt.Errorf("worktree created at %s, but session setup failed: %w", item.Path, err)
	}

	return item, id, nil
}
