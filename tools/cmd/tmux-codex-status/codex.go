package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

type rpcError struct {
	Message string
}

func (e *rpcError) Error() string { return e.Message }

type codexClient struct {
	conn *websocket.Conn
	id   int
}

func connect(ctx context.Context) (*codexClient, error) {
	home := os.Getenv("CODEX_HOME")
	if home == "" {
		userHome, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("resolve Codex home: %w", err)
		}

		home = filepath.Join(userHome, ".codex")
	}

	socket := filepath.Join(home, "app-server-control", "app-server-control.sock")
	transport := &http.Transport{DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "unix", socket)
	}}

	dialCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	conn, _, err := websocket.Dial(dialCtx, "ws://localhost", &websocket.DialOptions{ //nolint:bodyclose // websocket.Dial owns and closes the response body.
		HTTPClient: &http.Client{Transport: transport},
	})
	if err != nil {
		return nil, fmt.Errorf("connect to Codex: %w", err)
	}

	conn.SetReadLimit(16 << 20)
	client := &codexClient{conn: conn}

	err = client.call(ctx, "initialize", map[string]any{
		"clientInfo":   map[string]string{"name": "tmux_codex_status", "version": "1.0.0"},
		"capabilities": map[string]bool{"experimentalApi": true},
	}, nil)
	if err == nil {
		err = wsjson.Write(ctx, conn, map[string]any{"method": "initialized"})
	}

	if err != nil {
		_ = conn.CloseNow()
		return nil, fmt.Errorf("initialize Codex connection: %w", err)
	}

	return client, nil
}

func (c *codexClient) call(ctx context.Context, method string, params any, result any) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	c.id++
	if err := wsjson.Write(ctx, c.conn, map[string]any{
		"id": c.id, "method": method, "params": params,
	}); err != nil {
		return fmt.Errorf("send %s: %w", method, err)
	}

	for {
		var response struct {
			ID     int
			Result json.RawMessage
			Error  *rpcError
		}
		if err := wsjson.Read(ctx, c.conn, &response); err != nil {
			return fmt.Errorf("receive %s: %w", method, err)
		}

		if response.ID != c.id {
			continue
		}

		if response.Error != nil {
			return response.Error
		}

		if result == nil {
			return nil
		}

		if err := json.Unmarshal(response.Result, result); err != nil {
			return fmt.Errorf("decode %s: %w", method, err)
		}

		return nil
	}
}

func (c *codexClient) loadedIDs(ctx context.Context) ([]string, error) {
	ids := []string{}
	seen := map[string]bool{}

	var cursor *string

	for {
		var page struct {
			Data       []string
			NextCursor *string
		}

		err := c.call(ctx, "thread/loaded/list", map[string]any{"cursor": cursor, "limit": 100}, &page)
		if err != nil {
			return nil, err
		}

		for _, id := range page.Data {
			if !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}

		cursor = page.NextCursor
		if cursor == nil || *cursor == "" {
			return ids, nil
		}
	}
}

type thread struct {
	ID, Name, AgentNickname, Cwd, Preview string
	ParentThreadID, Model                 *string
	UpdatedAt                             *int64
	Status                                struct {
		Type        string
		ActiveFlags []string
	}
}

type readResult struct {
	Thread    thread
	ReadState *struct {
		FirstUnread *struct{ Type string }
	}
}

func (c *codexClient) readThread(ctx context.Context, id string) (readResult, error) {
	var result readResult

	err := c.call(ctx, "thread/read", map[string]any{"threadId": id, "includeTurns": false}, &result)

	return result, err
}
