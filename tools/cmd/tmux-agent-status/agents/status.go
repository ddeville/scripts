// Package agents collects running conversations and their tmux pane associations.
package agents

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/ddeville/scripts/tools/internal/codex"
)

var states = []string{"approval", "input", "error", "ready", "working", "idle", "unknown"}

// Type identifies the program running an agent.
type Type string

const (
	// Codex identifies a Codex agent.
	Codex Type = "codex"
	// Claude identifies a Claude agent.
	Claude Type = "claude"
)

// Agent describes a running conversation and its current status.
type Agent struct {
	ID             string   `json:"id"`
	Type           Type     `json:"agent_type"`
	Title          string   `json:"title"`
	Cwd            string   `json:"cwd"`
	Project        string   `json:"project"`
	State          string   `json:"status"`
	NeedsAttention bool     `json:"needs_attention"`
	Unread         *bool    `json:"unread"`
	ActiveFlags    []string `json:"active_flags"`
	ParentID       *string  `json:"parent_id"`
	Model          *string  `json:"model"`
	UpdatedAt      *int64   `json:"updated_at"`
	Error          *string  `json:"error"`
	Panes          []string `json:"tmux_panes,omitempty"`
	Preview        string   `json:"preview"`
}

// Snapshot contains the agents currently running in tmux and their status counts.
type Snapshot struct {
	SchemaVersion int            `json:"schema_version"`
	GeneratedAt   float64        `json:"generated_at"`
	Source        string         `json:"source"`
	Scope         string         `json:"scope"`
	IDs           []string       `json:"loaded_thread_ids"`
	Connection    Connection     `json:"connection"`
	Counts        map[string]int `json:"counts"`
	Agents        []Agent        `json:"agents"`
	At            time.Time      `json:"-"`
	Err           error          `json:"-"`
}

// Connection reports whether agent status could be collected.
type Connection struct {
	Status string  `json:"status"`
	Error  *string `json:"error"`
}

func rank(state string) int { return slices.Index(states, state) }

// Pane IDs remain stable across status changes, renames, and tmux reindexing.
func paneNumber(a Agent) int {
	number := math.MaxInt

	for _, pane := range a.Panes {
		if n, err := strconv.Atoi(strings.TrimPrefix(pane, "%")); err == nil {
			number = min(number, n)
		}
	}

	return number
}

func classify(result codex.ReadResult) string {
	switch result.Thread.Status.Type {
	case "active":
		flags := result.Thread.Status.ActiveFlags
		switch {
		case slices.Contains(flags, "waitingOnApproval"):
			return "approval"
		case slices.Contains(flags, "waitingOnUserInput"):
			return "input"
		case len(flags) != 0:
			return "unknown"
		default:
			return "working"
		}
	case "systemError":
		return "error"
	case "idle":
		if state := result.ReadState; state != nil && state.FirstUnread != nil && state.FirstUnread.Type == "turn" {
			return "ready"
		}

		return "idle"
	default:
		return "unknown"
	}
}

func agentRecord(result codex.ReadResult) Agent {
	t := result.Thread

	title := cmp.Or(t.Name, t.AgentNickname)
	if title == "" {
		preview := []rune(strings.Join(strings.Fields(t.Preview), " "))
		title = cmp.Or(string(preview[:min(100, len(preview))]), "New conversation")
	}

	state := classify(result)

	record := Agent{
		ID: t.ID, Type: Codex, Title: title, Cwd: t.Cwd, State: state, Preview: t.Preview,
		ParentID: t.ParentThreadID, Model: t.Model, UpdatedAt: t.UpdatedAt,
		ActiveFlags:    append([]string{}, t.Status.ActiveFlags...),
		NeedsAttention: rank(state) <= rank("ready"),
	}
	if t.Cwd != "" {
		record.Project = filepath.Base(t.Cwd)
	}

	if result.ReadState != nil {
		unread := result.ReadState.FirstUnread != nil
		record.Unread = &unread
	}

	return record
}

// Collect reads loaded conversations with live tmux panes, ordered by path and pane ID.
func Collect(ctx context.Context) (data Snapshot) {
	data = Snapshot{
		SchemaVersion: 1, Source: "codex", Scope: "tmux",
		IDs: []string{}, Agents: []Agent{}, Counts: map[string]int{},
		Connection: Connection{Status: "connected"},
	}
	defer func() {
		data.At = time.Now()

		data.GeneratedAt = float64(data.At.UnixMilli()) / 1000
		if data.Err != nil {
			message := data.Err.Error()
			data.Connection = Connection{Status: "unavailable", Error: &message}
			data.Agents = []Agent{}
		}

		for _, state := range states {
			data.Counts[state] = 0
		}

		data.Counts["total"], data.Counts["attention"] = len(data.Agents), 0
		for _, a := range data.Agents {
			data.Counts[a.State]++
			if a.NeedsAttention {
				data.Counts["attention"]++
			}
		}
	}()

	client, err := codex.Connect(ctx)
	if err != nil {
		data.Err = err
		return data
	}
	defer client.Close()

	ids, err := client.LoadedIDs(ctx)
	if err != nil {
		data.Err = err
		return data
	}

	data.IDs = ids

	panes, err := MatchPanes(ctx, ids)
	if err != nil {
		data.Err = err
		return data
	}

	for _, id := range ids {
		if len(panes[id]) == 0 {
			continue
		}

		result, err := client.ReadThread(ctx, id)
		if err != nil {
			var rpcErr *codex.RPCError
			if !errors.As(err, &rpcErr) {
				data.Err = err
				return data
			}

			data.Agents = append(data.Agents, Agent{
				ID: id, Type: Codex, Title: id, State: "error", NeedsAttention: true,
				Error: &rpcErr.Message, Panes: panes[id], ActiveFlags: []string{},
			})

			continue
		}

		if result.Thread.Status.Type == "notLoaded" {
			continue
		}

		record := agentRecord(result)
		record.Panes = panes[id]
		data.Agents = append(data.Agents, record)
	}

	slices.SortFunc(data.Agents, func(a, b Agent) int {
		return cmp.Or(
			cmp.Compare(a.Cwd, b.Cwd),
			cmp.Compare(paneNumber(a), paneNumber(b)),
			cmp.Compare(a.ID, b.ID),
		)
	})

	return data
}

// Details includes a conversation's status, initial prompt, and recent history.
type Details struct {
	Agent
	codex.History

	InitialPrompt string  `json:"initial_prompt"`
	HistoryError  *string `json:"history_error"`
}

// ReadDetails reads one conversation and its recent activity.
func ReadDetails(ctx context.Context, id string) (Details, error) {
	data := Details{RecentItems: []json.RawMessage{}}

	client, err := codex.Connect(ctx)
	if err != nil {
		return data, fmt.Errorf("read details for %s: %w", id, err)
	}
	defer client.Close()

	result, err := client.ReadThread(ctx, id)
	if err != nil {
		return data, fmt.Errorf("read details for %s: %w", id, err)
	}

	data.Agent, data.InitialPrompt = agentRecord(result), result.Thread.Preview

	data.History, err = client.ReadHistory(ctx, id)
	if err != nil {
		var rpcErr *codex.RPCError
		if !errors.As(err, &rpcErr) {
			return data, fmt.Errorf("read details for %s: %w", id, err)
		}

		data.HistoryError = &rpcErr.Message
	}

	return data, nil
}
