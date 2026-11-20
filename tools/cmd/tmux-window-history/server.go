package main

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/ddeville/scripts/tools/internal/tmux"
)

const eventsOption = "@window-history-events"

type socket string

func (s socket) run(ctx context.Context, args ...string) (string, error) {
	return tmux.RunOnSocket(ctx, string(s), args...)
}

type client struct {
	location string
	saved    string
	history  history
}

func (s socket) clients(ctx context.Context) (map[string]*client, error) {
	// Expand the client name to look up its history option in the same request.
	const format = "#{client_name}\t#{session_id}:#{window_id}\t#{E:##{@window-history-#{client_name}#}}"

	output, err := s.run(ctx, "list-clients", "-F", format)
	if err != nil {
		return nil, err
	}

	clients := make(map[string]*client)
	for line := range strings.Lines(output) {
		fields := strings.SplitN(strings.TrimSuffix(line, "\n"), "\t", 3)
		if len(fields) != 3 {
			return nil, fmt.Errorf("invalid tmux client record %q", line)
		}

		clients[fields[0]] = &client{location: fields[1], saved: fields[2], history: parseHistory(fields[2])}
	}

	return clients, nil
}

func (s socket) update(ctx context.Context, action, target string) (err error) {
	if _, err := s.run(ctx, "wait-for", "-L", "window-history"); err != nil {
		return err
	}

	// Finish applying the drained events and release the lock on interruption.
	ctx = context.WithoutCancel(ctx)
	defer func() {
		_, unlockErr := s.run(ctx, "wait-for", "-U", "window-history")
		err = errors.Join(err, unlockErr)
	}()

	events, err := s.run(ctx, "show-options", "-gqv", eventsOption, ";", "set-option", "-gqu", eventsOption)
	if err != nil || (action == "sync" && strings.TrimSpace(events) == "") {
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

	switch action {
	case "record":
		for _, c := range clients {
			c.history.visit(c.location)
		}
	case "back", "forward":
		if c := clients[target]; c != nil {
			c.history.visit(c.location)
			step := 1
			if action == "back" {
				step = -1
			}
			c.history.move(step, func(location string) bool {
				_, err := s.run(ctx, "switch-client", "-Z", "-c", target, "-t", location)
				return err == nil
			})
		}
	case "forget":
		if err := s.forget(ctx, clients, target); err != nil {
			return err
		}
	}

	for name, c := range clients {
		if value := c.history.String(); value != c.saved {
			if _, err := s.run(ctx, "set-option", "-gq", "@window-history-"+name, value); err != nil {
				return err
			}
		}
	}

	return nil
}

func (s socket) forget(ctx context.Context, clients map[string]*client, name string) error {
	_, err := s.run(ctx, "set-option", "-gqu", "@window-history-"+name)
	if c := clients[name]; c != nil {
		c.history = history{}
		c.saved = ""
	}

	return err
}
