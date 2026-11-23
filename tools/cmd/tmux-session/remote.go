package main

import (
	"context"
	"crypto/sha256"
	"fmt"
	"os/exec"
	"strings"

	"github.com/ddeville/scripts/tools/internal/remote"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

func findRemote(ctx context.Context, host, dir, name string) (tmux.Session, []tmux.Session, error) {
	sessions, err := tmux.ListSessions(ctx)
	if err != nil {
		return tmux.Session{}, nil, fmt.Errorf("list local sessions: %w", err)
	}

	for _, s := range sessions {
		if s.Remote == "" {
			continue
		}

		w, e := remote.Load(s.Remote)
		if e == nil && w.Matches(host, dir, name) {
			return s, sessions, nil
		}
	}

	return tmux.Session{}, sessions, nil
}

func openRemote(ctx context.Context, host, directory, name string) (tmux.Session, bool, error) {
	if _, err := exec.LookPath("tmux-remote"); err != nil {
		return tmux.Session{}, false, fmt.Errorf("locate tmux-remote: %w", err)
	}

	request := directory
	switch {
	case request == "~":
		request = "."
	case strings.HasPrefix(request, "~/"):
		request = strings.TrimPrefix(request, "~/")
	}

	s, _, err := findRemote(ctx, host, request, name)
	if err != nil || s.ID != "" {
		return s, false, err
	}

	hostLock, err := lockOpen(fmt.Sprintf("ssh-%x.lock", sha256.Sum256([]byte(host))))
	if err != nil {
		return tmux.Session{}, false, err
	}
	defer func() { _ = hostLock.Close() }()

	s, _, err = findRemote(ctx, host, request, name)
	if err != nil || s.ID != "" {
		return s, false, err
	}

	dir, w, err := remote.Prepare(ctx, host, request, name)
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("prepare remote workspace: %w", err)
	}

	created := false
	defer func() {
		if !created {
			remote.Cleanup(ctx, dir, w)
		}
	}()

	windows, err := w.DiscoverWindows(ctx, dir)
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("inspect workspace on %s: %w", host, err)
	}

	lock, err := lockOpen("open.lock")
	if err != nil {
		return tmux.Session{}, false, err
	}

	defer func() { _ = lock.Close() }()

	s, sessions, err := findRemote(ctx, host, w.Path, w.Name)
	if err != nil || s.ID != "" {
		return s, false, err
	}

	display := availableName(sessions, strings.NewReplacer(".", "_", ":", "_").Replace(host+"/"+w.Name))

	id, err := remote.Create(ctx, dir, w, display, windows)
	if err != nil {
		return tmux.Session{}, false, fmt.Errorf("create remote workspace: %w", err)
	}

	created = true

	return tmux.Session{ID: id, Name: display}, true, nil
}
