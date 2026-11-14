package tui_test

import (
	"context"
	"testing"
	"testing/synctest"

	tea "charm.land/bubbletea/v2"

	"github.com/ddeville/scripts/tools/internal/tui"
)

func TestTasksWaitsForCleanup(t *testing.T) {
	t.Parallel()

	synctest.Test(t, func(t *testing.T) {
		var tasks tui.Tasks

		ctx, cancel := context.WithCancel(t.Context())
		defer cancel()

		started, cleanup := make(chan struct{}), make(chan struct{})

		command := tasks.Track(func() tea.Msg {
			close(started)
			<-ctx.Done()
			<-cleanup

			return nil
		})
		go command()

		<-started
		cancel()

		queuedRan := false
		queued := tasks.Track(func() tea.Msg {
			queuedRan = true
			return nil
		})

		stopped := make(chan struct{})

		go func() {
			tasks.Wait()
			close(stopped)
		}()

		synctest.Wait()

		select {
		case <-stopped:
			t.Error("shutdown returned before cleanup finished")
		default:
		}

		queued()

		if queuedRan {
			t.Error("queued command started during shutdown")
		}

		close(cleanup)
		synctest.Wait()

		select {
		case <-stopped:
		default:
			t.Fatal("shutdown did not finish after cleanup")
		}
	})
}
