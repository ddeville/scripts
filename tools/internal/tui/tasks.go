package tui

import (
	"sync"

	tea "charm.land/bubbletea/v2"
)

// Tasks keeps commands that change external state alive until cleanup finishes.
// The zero value is ready to use.
type Tasks struct {
	mu      sync.Mutex
	stopped bool
	workers sync.WaitGroup
}

// Track registers a command when Bubble Tea starts it, unless shutdown has begun.
func (tasks *Tasks) Track(command tea.Cmd) tea.Cmd {
	return func() tea.Msg {
		tasks.mu.Lock()
		if tasks.stopped {
			tasks.mu.Unlock()
			return nil
		}

		tasks.workers.Add(1)
		tasks.mu.Unlock()

		defer tasks.workers.Done()

		return command()
	}
}

// Wait prevents queued commands from starting and waits for running commands.
// Cancel their contexts first so they can finish cleanup.
func (tasks *Tasks) Wait() {
	tasks.mu.Lock()
	tasks.stopped = true
	tasks.mu.Unlock()
	tasks.workers.Wait()
}
