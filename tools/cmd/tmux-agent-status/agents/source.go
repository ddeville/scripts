package agents

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/ddeville/scripts/tools/internal/codex"
	"github.com/ddeville/scripts/tools/internal/sshmux"
)

// Source shares one sequential app-server connection across status, activity,
// and navigation for a destination. Its zero value targets the local daemon.
type Source struct {
	Host string

	mu     sync.Mutex
	client *codex.Client
	slot   *os.File
}

func (s *Source) use(ctx context.Context, read func(*codex.Client) error) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := ctx.Err(); err != nil {
		return fmt.Errorf("read Codex: %w", err)
	}

	if s.client == nil {
		if err := s.connect(ctx); err != nil {
			return err
		}
	}

	err := read(s.client)

	var rpcErr *codex.RPCError
	if err != nil && !errors.As(err, &rpcErr) {
		s.close()
	}

	return err
}

func (s *Source) connect(ctx context.Context) error {
	if s.Host != "" {
		dest, err := sshmux.ForHost(s.Host)
		if err != nil {
			return fmt.Errorf("find SSH connection: %w", err)
		}

		s.slot, err = dest.ProxySlot(ctx)
		if err != nil {
			return fmt.Errorf("wait for SSH slot: %w", err)
		}

		go s.yield(dest, s.slot)
	}

	client, err := codex.Connect(ctx, s.Host)
	if err != nil {
		s.close()
		return fmt.Errorf("connect to app server: %w", err)
	}

	s.client = client

	return nil
}

// Keep the proxy warm between refreshes until another caller needs the slot.
// The mutex lets a request in flight finish before we return the channel.
func (s *Source) yield(dest sshmux.Destination, slot *os.File) {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for range ticker.C {
		s.mu.Lock()
		if s.slot == slot && dest.Waiting() {
			s.close()
		}

		done := s.slot != slot
		s.mu.Unlock()

		if done {
			return
		}
	}
}

// Close releases the app-server connection and its SSH channel, if any.
func (s *Source) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.close()
}

func (s *Source) close() {
	if s.client != nil {
		s.client.Close()
		s.client = nil
	}

	if s.slot != nil {
		_ = s.slot.Close()
		s.slot = nil
	}
}
