package main

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

var errThreadGone = errors.New("thread is no longer running in tmux")

func openThread(ctx context.Context, id string) error {
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()

	client, err := tmux.SingleClient(ctx)
	if err != nil {
		return fmt.Errorf("open agent: %w", err)
	}

	data := collect(ctx)
	if data.Err != nil {
		return data.Err
	}

	index := slices.IndexFunc(data.Agents, func(a agent) bool { return a.ID == id })
	if index < 0 {
		return errThreadGone
	}

	panes := data.Agents[index].Panes
	if len(panes) != 1 {
		return fmt.Errorf("%w, found %d", errPaneMatch, len(panes))
	}

	if err := tmux.SwitchPane(ctx, panes[0], client); err != nil {
		return fmt.Errorf("open agent: %w", err)
	}

	return nil
}
