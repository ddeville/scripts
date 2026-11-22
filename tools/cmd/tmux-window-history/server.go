package main

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

const (
	eventsOption        = "@window-history-events"
	historyOptionPrefix = "@window-history-"
	historyLock         = "window-history"
)

var errInvalidClientRecord = errors.New("invalid tmux client record")

type socket string

func (s socket) run(ctx context.Context, args ...string) (string, error) {
	output, err := tmux.RunOnSocket(ctx, string(s), args...)
	if err != nil {
		return output, fmt.Errorf("run tmux command: %w", err)
	}

	return output, nil
}

type client struct {
	location string
	saved    string
	history  history
}

func (s socket) clients(ctx context.Context) (map[string]*client, error) {
	// Expand the client name to look up its history option in the same request.
	const (
		historyField = "#{E:##{" + historyOptionPrefix + "#{client_name}#}}"
		format       = "#{client_name}\t#{session_id}:#{window_id}\t" + historyField
	)

	output, err := s.run(ctx, "list-clients", "-F", format)
	if err != nil {
		return nil, err
	}

	clients := make(map[string]*client)

	for line := range strings.Lines(output) {
		fields := strings.SplitN(strings.TrimSuffix(line, "\n"), "\t", 3)
		if len(fields) != 3 {
			return nil, fmt.Errorf("%w %q", errInvalidClientRecord, line)
		}

		clients[fields[0]] = &client{
			location: fields[1],
			saved:    fields[2],
			history:  parseHistory(fields[2]),
		}
	}

	return clients, nil
}

// update replays queued events, applies an optional edit, and saves the changed histories under one lock.
func (s socket) update(ctx context.Context, edit func(context.Context, map[string]*client) error) (err error) {
	if _, err := s.run(ctx, "wait-for", "-L", historyLock); err != nil {
		return err
	}

	// Finish applying the drained events and release the lock on interruption.
	ctx = context.WithoutCancel(ctx)
	defer func() {
		_, unlockErr := s.run(ctx, "wait-for", "-U", historyLock)
		err = errors.Join(err, unlockErr)
	}()

	events, err := s.run(ctx, "show-options", "-gqv", eventsOption, ";", "set-option", "-gqu", eventsOption)
	if err != nil || (edit == nil && strings.TrimSpace(events) == "") {
		return err
	}

	clients, err := s.clients(ctx)
	if err != nil {
		return err
	}

	// Replay the hooks before using a client's current location for a key press.
	for line := range strings.Lines(events) {
		event, args, _ := strings.Cut(strings.TrimSpace(line), " ")
		switch event {
		case "client-visit":
			name, location, _ := strings.Cut(args, " ")
			if c := clients[name]; c != nil {
				c.history.visit(location)
			}
		case "window-visit":
			session, _, _ := strings.Cut(args, ":")
			for _, c := range clients {
				// The cursor tracks membership at the time of this event.
				if strings.HasPrefix(c.history.current(), session+":") {
					c.history.visit(args)
				}
			}
		case "forget":
			if err := s.forget(ctx, clients, args); err != nil {
				return err
			}
		}
	}

	if edit != nil {
		if err := edit(ctx, clients); err != nil {
			return err
		}
	}

	for name, c := range clients {
		if value := c.history.String(); value != c.saved {
			if _, err := s.run(ctx, "set-option", "-gq", historyOptionPrefix+name, value); err != nil {
				return err
			}
		}
	}

	return nil
}

func recordVisits(_ context.Context, clients map[string]*client) error {
	for _, c := range clients {
		c.history.visit(c.location)
	}

	return nil
}

func (s socket) moveClient(ctx context.Context, name string, dir direction) error {
	return s.update(ctx, func(ctx context.Context, clients map[string]*client) error {
		if c := clients[name]; c != nil {
			c.history.visit(c.location)
			c.history.move(dir, func(location string) bool {
				_, err := s.run(ctx, "switch-client", "-Z", "-c", name, "-t", location)
				return err == nil
			})
		}

		return nil
	})
}

func (s socket) forgetClient(ctx context.Context, name string) error {
	return s.update(ctx, func(ctx context.Context, clients map[string]*client) error {
		return s.forget(ctx, clients, name)
	})
}

func (s socket) forget(ctx context.Context, clients map[string]*client, name string) error {
	_, err := s.run(ctx, "set-option", "-gqu", historyOptionPrefix+name)
	if c := clients[name]; c != nil {
		c.history = history{}
		c.saved = ""
	}

	return err
}
