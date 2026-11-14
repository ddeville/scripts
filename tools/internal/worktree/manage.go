package worktree

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
	// ErrDirty prevents removing or implicitly copying uncommitted work.
	ErrDirty = errors.New("worktree has local changes")
	// ErrUnmergedDetached prevents discarding commits without a branch to keep.
	ErrUnmergedDetached = errors.New("detached HEAD has unmerged commits; create a branch before removing it")
	errInvalidName      = errors.New("worktree name must be a single directory name")
)

// CreateOptions selects the source checkout, committed base, and session setup.
type CreateOptions struct {
	Directory string
	Name      string
	Base      string
	Fork      string
	NoTmux    bool
}

func createWorktree(ctx context.Context, root string, options CreateOptions) (Info, error) {
	if options.Name == "" || options.Name == "." || options.Name == ".." || filepath.Base(options.Name) != options.Name {
		return Info{}, errInvalidName
	}

	source, main, err := git.Locate(ctx, options.Directory)
	if err != nil {
		return Info{}, fmt.Errorf("locate repository: %w", err)
	}

	base := options.Base
	if base == "" {
		state, statusErr := git.Status(ctx, source)
		if statusErr != nil {
			return Info{}, fmt.Errorf("check source worktree: %w", statusErr)
		}

		if state != "clean" {
			return Info{}, fmt.Errorf("%w; pass --base HEAD to leave changes in the source checkout", ErrDirty)
		}

		base = "HEAD"
	}

	commit, err := git.ResolveCommit(ctx, source, base)
	if err != nil {
		return Info{}, fmt.Errorf("resolve base commit: %w", err)
	}

	path, err := filepath.Abs(filepath.Join(root, filepath.Base(main), options.Name))
	if err != nil {
		return Info{}, fmt.Errorf("resolve worktree path: %w", err)
	}

	if _, err := os.Lstat(path); !errors.Is(err, os.ErrNotExist) {
		if err != nil {
			return Info{}, fmt.Errorf("check worktree path: %w", err)
		}

		return Info{}, fmt.Errorf("%w: %s", os.ErrExist, path)
	}

	branch := "damien/cw/" + options.Name
	if err := git.AddWorktree(ctx, source, path, branch, commit); err != nil {
		return Info{}, fmt.Errorf("add worktree: %w", err)
	}

	return Info{Repo: filepath.Base(main), Name: options.Name, Path: canonical(path), Branch: branch}, nil
}

// Resolve accepts a managed name, repo/name, path, or the current checkout.
func Resolve(ctx context.Context, root, directory, target string) (Info, error) {
	if target == "" || target == "." {
		return inspect(ctx, directory)
	}

	items, err := Discover(root)
	if err != nil {
		return Info{}, err
	}

	_, main, _ := git.Locate(ctx, directory)

	var matches []Info

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
		return Info{}, fmt.Errorf("%w: %s matches several repositories; use repo/name or a path", os.ErrInvalid, target)
	}

	path := target
	if !filepath.IsAbs(path) {
		path = filepath.Join(directory, path)
	}

	return inspect(ctx, path)
}

func inspect(ctx context.Context, path string) (Info, error) {
	source, main, err := git.Locate(ctx, path)
	if err != nil {
		return Info{}, fmt.Errorf("locate repository: %w", err)
	}

	if source == main {
		return Info{}, fmt.Errorf("%w: %s is the main checkout", git.ErrNotLinkedWorktree, source)
	}

	item, err := readCheckout(source)
	if err != nil {
		return Info{}, fmt.Errorf("%s: %w", source, err)
	}

	item.Repo, item.Name = filepath.Base(main), filepath.Base(source)

	return item, nil
}

// Removal records the checkout, branch, and sessions reviewed before deletion.
type Removal struct {
	Worktree Info
	Branch   string
	Sessions []tmux.Session
	MainPath string
}

// PlanRemoval refuses dirty checkouts and branches with unmerged commits.
func PlanRemoval(ctx context.Context, item Info, keepBranch bool) (Removal, error) {
	item, err := inspect(ctx, item.Path)
	if err != nil {
		return Removal{}, err
	}

	state, err := git.Status(ctx, item.Path)
	if err != nil {
		return Removal{}, fmt.Errorf("check worktree status: %w", err)
	}

	if state != "clean" {
		return Removal{}, fmt.Errorf("%w: %s", ErrDirty, item.Path)
	}

	_, main, err := git.Locate(ctx, item.Path)
	if err != nil {
		return Removal{}, fmt.Errorf("locate repository: %w", err)
	}

	plan := Removal{Worktree: item, MainPath: main}

	branch, err := git.CurrentBranch(ctx, item.Path)
	if err != nil {
		return Removal{}, fmt.Errorf("read branch: %w", err)
	}

	if branch == "" {
		commit, err := git.ResolveCommit(ctx, item.Path, "HEAD")
		if err != nil {
			return Removal{}, fmt.Errorf("read detached HEAD: %w", err)
		}

		if err := git.CheckMerged(ctx, main, commit); err != nil {
			return Removal{}, fmt.Errorf("%w: %w", ErrUnmergedDetached, err)
		}
	}

	if !keepBranch {
		plan.Branch = branch
		if plan.Branch != "" {
			if err := git.CheckMerged(ctx, main, plan.Branch); err != nil {
				return Removal{}, fmt.Errorf("%w; use --keep-branch to retain it", err)
			}
		}
	}

	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return Removal{}, fmt.Errorf("list sessions: %w", err)
	}

	for _, session := range sessions {
		if session.Path == item.Path {
			plan.Sessions = append(plan.Sessions, session)
		}
	}

	return plan, nil
}

// Remove rechecks a removal plan before removing its checkout and resources.
func Remove(ctx context.Context, plan Removal) error {
	current, err := PlanRemoval(ctx, plan.Worktree, plan.Branch == "")
	if err != nil {
		return err
	}

	if current.Worktree.Branch != plan.Worktree.Branch || current.Branch != plan.Branch || !slices.Equal(current.Sessions, plan.Sessions) {
		return fmt.Errorf("%w: worktree branch or tmux sessions changed; run remove again", os.ErrInvalid)
	}

	if err := git.RemoveWorktree(ctx, current.MainPath, current.Worktree.Path); err != nil {
		return fmt.Errorf("remove Git worktree: %w", err)
	}

	var cleanupErrors []error

	if current.Branch != "" {
		if err := git.DeleteBranch(ctx, current.MainPath, current.Branch); err != nil {
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
