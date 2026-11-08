"""Read local Codex state without subscribing to or resuming conversations."""

import json
import os
import tempfile
import time
from contextlib import ExitStack
from pathlib import Path
from typing import Any

from websockets.exceptions import WebSocketException
from websockets.sync.client import ClientConnection, unix_connect

from tmux_codex_status.tmux import pane_matches

type JsonObject = dict[str, Any]

STATES = ("approval", "input", "error", "ready", "working", "idle", "unknown")
ATTENTION = {"approval", "input", "error", "ready"}


class RpcError(Exception):
    """An error returned by a Codex RPC request."""


class CodexClient:
    """A synchronous client for the local Codex app server."""

    def __init__(self, socket_path: str) -> None:
        """Set up a client for the local Codex socket."""
        self.socket_path = socket_path
        self.connection: ClientConnection | None = None
        self.connection_context = ExitStack()
        self.request_id = 0
        self.deadline = 0.0

    def close(self) -> None:
        """Close the connection if one is open."""
        if self.connection is not None:
            self.connection_context.close()
            self.connection = None

    def connect(self) -> None:
        """Open a connection if needed and reset the request deadline."""
        self.deadline = time.monotonic() + 8
        if self.connection is None:
            self.connection = self.connection_context.enter_context(
                unix_connect(
                    self.socket_path,
                    open_timeout=2,
                    close_timeout=0.2,
                    max_size=16 * 1024 * 1024,
                )
            )
            self.call(
                "initialize",
                {
                    "clientInfo": {"name": "tmux_codex_status", "version": "1.0.0"},
                    "capabilities": {"experimentalApi": True},
                },
            )
            self.connection.send(json.dumps({"method": "initialized"}))

    def call(self, method: str, params: JsonObject) -> JsonObject:
        """Send an RPC request and wait for its response."""
        assert self.connection is not None
        self.request_id += 1
        request_id = self.request_id
        self.connection.send(json.dumps({"id": request_id, "method": method, "params": params}))
        while True:
            remaining = min(3, self.deadline - time.monotonic())
            if remaining <= 0:
                raise TimeoutError("Timed out reading Codex state")
            message = json.loads(self.connection.recv(timeout=remaining))
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RpcError(message["error"]["message"])
            return message["result"]

    def loaded_ids(self) -> list[str]:
        """List unique conversation IDs currently loaded by Codex."""
        ids: list[str] = []
        cursor = None
        while True:
            page = self.call("thread/loaded/list", {"cursor": cursor, "limit": 100})
            ids.extend(page["data"])
            cursor = page.get("nextCursor")
            if not cursor:
                return list(dict.fromkeys(ids))


def classify(status: JsonObject, read_state: JsonObject | None) -> str:
    """Map Codex status and unread state to a dashboard status."""
    kind = status.get("type")
    flags = status.get("activeFlags", [])
    if kind == "active":
        if "waitingOnApproval" in flags:
            return "approval"
        if "waitingOnUserInput" in flags:
            return "input"
        return "unknown" if flags else "working"
    if kind == "systemError":
        return "error"
    if kind == "idle":
        unread = (read_state or {}).get("firstUnread") or {}
        return "ready" if unread.get("type") == "turn" else "idle"
    return "unknown"


def agent_record(thread: JsonObject, read_state: JsonObject | None) -> JsonObject:
    """Build a dashboard record from conversation metadata."""
    status = classify(thread.get("status", {}), read_state)
    cwd = thread.get("cwd") or ""
    title = thread.get("name") or thread.get("agentNickname")
    if not title:
        title = " ".join(thread.get("preview", "").split())[:100] or "New conversation"
    return {
        "id": thread["id"],
        "title": title,
        "cwd": cwd,
        "project": Path(cwd).name if cwd else "",
        "status": status,
        "needs_attention": status in ATTENTION,
        "unread": None if read_state is None else read_state.get("firstUnread") is not None,
        "active_flags": thread.get("status", {}).get("activeFlags", []),
        "parent_id": thread.get("parentThreadId"),
        "model": thread.get("model"),
        "updated_at": thread.get("updatedAt"),
        "error": None,
    }


def snapshot(client: CodexClient) -> JsonObject:
    """Collect current conversations, status counts, and connection health."""
    agents: list[JsonObject] = []
    error = None
    try:
        client.connect()
        for thread_id in client.loaded_ids():
            try:
                result = client.call("thread/read", {"threadId": thread_id, "includeTurns": False})
                thread = result["thread"]
                # A thread can unload between the enumeration and metadata read.
                if thread.get("status", {}).get("type") != "notLoaded":
                    agents.append(agent_record(thread, result.get("readState")))
            except RpcError as exc:
                record = agent_record({"id": thread_id, "name": thread_id}, None)
                record["error"] = str(exc)
                agents.append(record)
    except (OSError, WebSocketException, RpcError, ValueError) as exc:
        client.close()
        agents = []
        error = str(exc) or type(exc).__name__
    panes = pane_matches([agent["id"] for agent in agents])
    for agent in agents:
        agent["tmux_panes"] = panes.get(agent["id"], [])
    agents.sort(
        key=lambda agent: (
            STATES.index(agent["status"]),
            agent["project"].casefold(),
            agent["title"].casefold(),
            agent["id"],
        )
    )
    counts = {state: sum(agent["status"] == state for agent in agents) for state in STATES}
    counts["total"] = len(agents)
    counts["attention"] = sum(agent["needs_attention"] for agent in agents)
    return {
        "schema_version": 1,
        "generated_at": time.time(),
        "source": "codex",
        "scope": "loaded",
        "connection": {
            "status": "unavailable" if error else "connected",
            "error": error,
        },
        "counts": counts,
        "agents": agents,
    }


def detail(client: CodexClient, thread_id: str) -> JsonObject:
    """Fetch a conversation's metadata and recent activity."""
    client.connect()
    result = client.call("thread/read", {"threadId": thread_id, "includeTurns": False})
    record = agent_record(result["thread"], result.get("readState"))
    record["initial_prompt"] = result["thread"].get("preview", "")
    record["latest_turn"] = None
    record["recent_items"] = []
    record["history_error"] = None
    try:
        turns = client.call(
            "thread/turns/list",
            {
                "threadId": thread_id,
                "limit": 1,
                "sortDirection": "desc",
                "itemsView": "summary",
            },
        )
        record["latest_turn"] = next(iter(turns["data"]), None)
        if record["latest_turn"]:
            items = client.call(
                "thread/items/list",
                {
                    "threadId": thread_id,
                    "turnId": record["latest_turn"]["id"],
                    "limit": 6,
                    "sortDirection": "desc",
                },
            )
            record["recent_items"] = items["data"]
    except RpcError as exc:
        # Empty or legacy conversations may not support paginated history.
        record["history_error"] = str(exc)
    return record


def write_snapshot(path: Path, data: JsonObject) -> None:
    """Atomically replace the snapshot file with fresh JSON."""
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        delete=False,
    ) as output:
        temporary = Path(output.name)
        try:
            json.dump(data, output, ensure_ascii=False)
            output.write("\n")
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def run(
    watch: bool,
    interval: float,
    output: Path | None,
    thread_id: str | None,
) -> None:
    """Write one snapshot or keep publishing updates."""
    socket_path = (
        Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
        / "app-server-control/app-server-control.sock"
    )
    client = CodexClient(str(socket_path))
    try:
        while True:
            started = time.monotonic()
            data = detail(client, thread_id) if thread_id else snapshot(client)
            if output:
                write_snapshot(output, data)
            else:
                print(json.dumps(data, ensure_ascii=False), flush=True)
            if not watch:
                return
            time.sleep(max(0, interval - (time.monotonic() - started)))
    finally:
        client.close()
