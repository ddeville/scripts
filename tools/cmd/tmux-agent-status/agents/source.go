package agents

import (
	"context"
	"errors"
	"fmt"
	"sync"

	"github.com/ddeville/scripts/tools/internal/codex"
)

// Source shares one sequential app-server connection across status, activity,
// and navigation for a destination. Its zero value targets the local daemon.
type Source struct {
	Host string

	mu     sync.Mutex
	client *codex.Client
}

func (s *Source) use(ctx context.Context, read func(*codex.Client) error) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := ctx.Err(); err != nil {
		return fmt.Errorf("read Codex: %w", err)
	}

	if s.client == nil {
		client, err := codex.Connect(ctx, s.Host)
		if err != nil {
			return fmt.Errorf("connect to app server: %w", err)
		}

		s.client = client
	}

	err := read(s.client)

	var rpcErr *codex.RPCError
	if err != nil && !errors.As(err, &rpcErr) {
		s.client.Close()
		s.client = nil
	}

	return err
}

// Close releases the app-server connection and its SSH channel, if any.
func (s *Source) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.client != nil {
		s.client.Close()
		s.client = nil
	}
}
