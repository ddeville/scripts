// Package agentstatus collects agent status and presents it as a picker or JSON.
package agentstatus

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/ddeville/scripts/tools/internal/codex"
	"github.com/ddeville/scripts/tools/internal/tmux"
)

var states = []string{"approval", "input", "error", "ready", "working", "idle", "unknown"}

// AgentType identifies the program running an agent.
type AgentType string

const (
	// AgentTypeCodex identifies a Codex agent.
	AgentTypeCodex AgentType = "codex"
	// AgentTypeClaude identifies a Claude agent.
	AgentTypeClaude AgentType = "claude"
)

type agent struct {
	ID             string    `json:"id"`
	Type           AgentType `json:"agent_type"`
	Title          string    `json:"title"`
	Cwd            string    `json:"cwd"`
	Project        string    `json:"project"`
	State          string    `json:"status"`
	NeedsAttention bool      `json:"needs_attention"`
	Unread         *bool     `json:"unread"`
	ActiveFlags    []string  `json:"active_flags"`
	ParentID       *string   `json:"parent_id"`
	Model          *string   `json:"model"`
	UpdatedAt      *int64    `json:"updated_at"`
	Error          *string   `json:"error"`
	Panes          []string  `json:"tmux_panes,omitempty"`
	Preview        string    `json:"preview"`
}

type snapshot struct {
	SchemaVersion int            `json:"schema_version"`
	GeneratedAt   float64        `json:"generated_at"`
	Source        string         `json:"source"`
	Scope         string         `json:"scope"`
	IDs           []string       `json:"loaded_thread_ids"`
	Connection    connection     `json:"connection"`
	Counts        map[string]int `json:"counts"`
	Agents        []agent        `json:"agents"`
	At            time.Time      `json:"-"`
	Err           error          `json:"-"`
}

type connection struct {
	Status string  `json:"status"`
	Error  *string `json:"error"`
}

func rank(state string) int { return slices.Index(states, state) }

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

func agentRecord(result codex.ReadResult) agent {
	t := result.Thread

	title := cmp.Or(t.Name, t.AgentNickname)
	if title == "" {
		preview := []rune(strings.Join(strings.Fields(t.Preview), " "))
		title = cmp.Or(string(preview[:min(100, len(preview))]), "New conversation")
	}

	state := classify(result)

	record := agent{
		ID: t.ID, Type: AgentTypeCodex, Title: title, Cwd: t.Cwd, State: state, Preview: t.Preview,
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

func collect(ctx context.Context) (data snapshot) {
	data = snapshot{
		SchemaVersion: 1, Source: "codex", Scope: "tmux",
		IDs: []string{}, Agents: []agent{}, Counts: map[string]int{},
		Connection: connection{Status: "connected"},
	}
	defer func() {
		data.At = time.Now()

		data.GeneratedAt = float64(data.At.UnixMilli()) / 1000
		if data.Err != nil {
			message := data.Err.Error()
			data.Connection = connection{Status: "unavailable", Error: &message}
			data.Agents = []agent{}
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

	panes, err := tmux.PaneMatches(ctx, ids)
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

			data.Agents = append(data.Agents, agent{
				ID: id, Type: AgentTypeCodex, Title: id, State: "error", NeedsAttention: true,
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

	slices.SortFunc(data.Agents, func(a, b agent) int {
		return cmp.Or(
			cmp.Compare(rank(a.State), rank(b.State)),
			strings.Compare(strings.ToLower(a.Cwd), strings.ToLower(b.Cwd)),
			strings.Compare(strings.ToLower(a.Title), strings.ToLower(b.Title)),
			strings.Compare(a.ID, b.ID),
		)
	})

	return data
}

type threadDetails struct {
	agent
	codex.History

	InitialPrompt string  `json:"initial_prompt"`
	HistoryError  *string `json:"history_error"`
}

func detail(ctx context.Context, id string) (threadDetails, error) {
	data := threadDetails{RecentItems: []json.RawMessage{}}

	client, err := codex.Connect(ctx)
	if err != nil {
		return data, fmt.Errorf("read details for %s: %w", id, err)
	}
	defer client.Close()

	result, err := client.ReadThread(ctx, id)
	if err != nil {
		return data, fmt.Errorf("read details for %s: %w", id, err)
	}

	data.agent, data.InitialPrompt = agentRecord(result), result.Thread.Preview

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
