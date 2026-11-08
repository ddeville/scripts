"""Read local Codex state without subscribing to or resuming conversations."""

import asyncio
import json
import os
import tempfile
import time
from contextlib import aclosing
from pathlib import Path
from typing import Any, Literal

from websockets.asyncio.client import ClientConnection, unix_connect
from websockets.exceptions import WebSocketException

from tmux_codex_status.tmux import pane_matches

type JsonObject = dict[str, Any]
type AgentState = Literal["approval", "input", "error", "ready", "working", "idle", "unknown"]

STATES: tuple[AgentState, ...] = (
    "approval",
    "input",
    "error",
    "ready",
    "working",
    "idle",
    "unknown",
)
ATTENTION = {"approval", "input", "error", "ready"}


class RpcError(Exception):
    """An error returned by a Codex RPC request."""


class CodexClient:
    """An async client for the local Codex app server."""

    def __init__(self, socket_path: str | None = None) -> None:
        """Set up a client for the local Codex socket."""
        self.socket_path = socket_path or str(
            Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
            / "app-server-control/app-server-control.sock"
        )
        self.connection: ClientConnection | None = None
        self.request_id = 0
        self.deadline = 0.0

    async def aclose(self) -> None:
        """Close the connection if one is open."""
        if self.connection is not None:
            await self.connection.close()
            self.connection = None

    async def connect(self) -> None:
        """Open a connection if needed and reset the request deadline."""
        self.deadline = time.monotonic() + 8
        if self.connection is not None:
            return
        self.connection = await unix_connect(
            self.socket_path,
            open_timeout=2,
            close_timeout=0.2,
            max_size=16 * 1024 * 1024,
        )
        await self.call(
            "initialize",
            {
                "clientInfo": {"name": "tmux_codex_status", "version": "1.0.0"},
                "capabilities": {"experimentalApi": True},
            },
        )
        await self.connection.send(json.dumps({"method": "initialized"}))

    async def call(self, method: str, params: JsonObject) -> JsonObject:
        """Send an RPC request and wait for its response."""
        assert self.connection is not None
        self.request_id += 1
        request_id = self.request_id
        await self.connection.send(
            json.dumps({"id": request_id, "method": method, "params": params})
        )
        while True:
            remaining = min(3, self.deadline - time.monotonic())
            if remaining <= 0:
                raise TimeoutError("Timed out reading Codex state")
            async with asyncio.timeout(remaining):
                message = json.loads(await self.connection.recv())
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RpcError(message["error"]["message"])
            return message["result"]

    async def loaded_ids(self) -> list[str]:
        """List unique conversation IDs currently loaded by Codex."""
        ids: list[str] = []
        cursor = None
        while True:
            page = await self.call("thread/loaded/list", {"cursor": cursor, "limit": 100})
            ids.extend(page["data"])
            cursor = page.get("nextCursor")
            if not cursor:
                return list(dict.fromkeys(ids))


def classify(status: JsonObject, read_state: JsonObject | None) -> AgentState:
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


async def snapshot(client: CodexClient) -> JsonObject:
    """Collect loaded conversations in this tmux server and their status."""
    agents: list[JsonObject] = []
    thread_ids: list[str] = []
    error = None
    try:
        await client.connect()
        thread_ids = await client.loaded_ids()
        panes = await asyncio.to_thread(pane_matches, thread_ids)
        for thread_id, thread_panes in panes.items():
            try:
                result = await client.call(
                    "thread/read", {"threadId": thread_id, "includeTurns": False}
                )
                thread = result["thread"]
                # A thread can unload between the enumeration and metadata read.
                if thread.get("status", {}).get("type") == "notLoaded":
                    continue
                record = agent_record(thread, result.get("readState"))
            except RpcError as exc:
                record = agent_record({"id": thread_id, "name": thread_id}, None)
                record["error"] = str(exc)
            record["tmux_panes"] = thread_panes
            agents.append(record)
    except (OSError, WebSocketException, RpcError, ValueError) as exc:
        await client.aclose()
        agents = []
        error = str(exc) or type(exc).__name__
    agents.sort(
        key=lambda agent: (
            STATES.index(agent["status"]),
            agent["project"].casefold(),
            agent["title"].casefold(),
            agent["id"],
        )
    )
    counts: dict[str, int] = {
        state: sum(agent["status"] == state for agent in agents) for state in STATES
    }
    counts["total"] = len(agents)
    counts["attention"] = sum(agent["needs_attention"] for agent in agents)
    return {
        "schema_version": 1,
        "generated_at": time.time(),
        "source": "codex",
        "scope": "tmux",
        "loaded_thread_ids": thread_ids,
        "connection": {
            "status": "unavailable" if error else "connected",
            "error": error,
        },
        "counts": counts,
        "agents": agents,
    }


async def detail(client: CodexClient, thread_id: str) -> JsonObject:
    """Fetch a conversation's metadata and recent activity."""
    await client.connect()
    result = await client.call("thread/read", {"threadId": thread_id, "includeTurns": False})
    record = {
        **agent_record(result["thread"], result.get("readState")),
        "initial_prompt": result["thread"].get("preview", ""),
        "latest_turn": None,
        "recent_items": [],
        "history_error": None,
    }
    try:
        turns = await client.call(
            "thread/turns/list",
            {
                "threadId": thread_id,
                "limit": 1,
                "sortDirection": "desc",
                "itemsView": "summary",
            },
        )
        turn_data: list[JsonObject] = turns["data"]
        latest_turn = turn_data[0] if turn_data else None
        record["latest_turn"] = latest_turn
        if latest_turn:
            items = await client.call(
                "thread/items/list",
                {
                    "threadId": thread_id,
                    "turnId": latest_turn["id"],
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


async def run(
    watch: bool,
    interval: float,
    output: Path | None,
    thread_id: str | None,
) -> None:
    """Write one snapshot or keep publishing updates."""
    async with aclosing(CodexClient()) as client:
        while True:
            started = time.monotonic()
            if thread_id:
                data = await detail(client, thread_id)
            else:
                data = await snapshot(client)
            if output:
                write_snapshot(output, data)
            else:
                print(json.dumps(data, ensure_ascii=False), flush=True)
            if not watch:
                return
            await asyncio.sleep(max(0, interval - (time.monotonic() - started)))
