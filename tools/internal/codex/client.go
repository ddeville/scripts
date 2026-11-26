// Package codex provides a client for the local Codex app server.
package codex

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

// RPCError is an error returned by the app server.
type RPCError struct {
	Message string
}

func (e *RPCError) Error() string { return e.Message }

// Client sends sequential requests over a local app-server connection.
type Client struct {
	conn *websocket.Conn
	id   int
}

// Connect opens and initializes an app-server connection.
func Connect(ctx context.Context) (*Client, error) {
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
	defer transport.CloseIdleConnections()

	dialCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	conn, _, err := websocket.Dial(dialCtx, "ws://localhost", &websocket.DialOptions{ //nolint:bodyclose // websocket.Dial owns and closes the response body.
		HTTPClient: &http.Client{Transport: transport},
	})
	if err != nil {
		return nil, fmt.Errorf("connect to Codex: %w", err)
	}

	conn.SetReadLimit(16 << 20)
	client := &Client{conn: conn}

	err = client.call(ctx, "initialize", map[string]any{
		"clientInfo":   map[string]string{"name": "tmux_agent_status", "version": "1.0.0"},
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

// Close releases the connection without waiting for a closing handshake.
func (c *Client) Close() { _ = c.conn.CloseNow() }

func (c *Client) call(ctx context.Context, method string, params any, result any) error {
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
			Error  *RPCError
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

// LoadedIDs lists the threads currently loaded by the app server.
func (c *Client) LoadedIDs(ctx context.Context) ([]string, error) {
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

// Thread contains the metadata used to describe an agent.
type Thread struct {
	ID, Name, AgentNickname, Cwd, Preview string
	ParentThreadID, Model                 *string
	UpdatedAt                             *int64
	Status                                struct {
		Type        string
		ActiveFlags []string
	}
}

// ReadResult includes thread metadata and unread state.
type ReadResult struct {
	Thread    Thread
	ReadState *struct {
		FirstUnread *struct{ Type string }
	}
}

// ReadThread reads metadata without loading the full conversation history.
func (c *Client) ReadThread(ctx context.Context, id string) (ReadResult, error) {
	var result ReadResult

	err := c.call(ctx, "thread/read", map[string]any{"threadId": id, "includeTurns": false}, &result)

	return result, err
}

// History contains the latest turn and its most recent items.
type History struct {
	LatestTurn  json.RawMessage   `json:"latest_turn"`
	RecentItems []json.RawMessage `json:"recent_items"`
}

// ReadHistory reads recent activity, retaining the latest turn if its items cannot be read.
func (c *Client) ReadHistory(ctx context.Context, id string) (History, error) {
	data := History{RecentItems: []json.RawMessage{}}

	var turns struct{ Data []json.RawMessage }

	err := c.call(ctx, "thread/turns/list", map[string]any{
		"threadId": id, "limit": 1, "sortDirection": "desc", "itemsView": "summary",
	}, &turns)
	if err != nil || len(turns.Data) == 0 {
		return data, err
	}

	data.LatestTurn = turns.Data[0]

	var turn struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(data.LatestTurn, &turn); err != nil {
		return data, fmt.Errorf("decode latest turn: %w", err)
	}

	var items struct{ Data []json.RawMessage }

	err = c.call(ctx, "thread/items/list", map[string]any{
		"threadId": id, "turnId": turn.ID, "limit": 6, "sortDirection": "desc",
	}, &items)
	if err == nil && items.Data != nil {
		data.RecentItems = items.Data
	}

	return data, err
}
