package main

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/ddeville/scripts/tools/cmd/tmux-agent-status/agents"
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

	var local agents.Source
	defer local.Close()

	data := local.Collect(ctx, nil)
	if data.Err != nil {
		return data.Err
	}

	index := slices.IndexFunc(data.Agents, func(a agents.Agent) bool { return a.ID == id })
	if index < 0 {
		return errThreadGone
	}

	panes := data.Agents[index].Targets
	if len(panes) != 1 {
		return fmt.Errorf("%w, found %d", agents.ErrPaneMatch, len(panes))
	}

	if err := local.Open(ctx, id, panes[0], client); err != nil {
		return fmt.Errorf("open agent: %w", err)
	}

	return nil
}
