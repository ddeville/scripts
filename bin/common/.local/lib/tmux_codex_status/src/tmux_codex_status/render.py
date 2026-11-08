"""Render Codex conversations and navigate to their tmux panes."""

import json
import os
import shlex
import sys
import time
from pathlib import Path
from typing import Any

type JsonObject = dict[str, Any]

STYLES = {
    "approval": (31, "Approval"),
    "input": (31, "Input"),
    "ready": (32, "Ready"),
    "working": (36, "Working"),
    "idle": (90, "Idle"),
    "error": (35, "Error"),
    "unknown": (90, "Unknown"),
}


def clean(value: object, multiline: bool = False) -> str:
    """Remove control characters and normalize whitespace for display."""
    text = str(value or "")
    if multiline:
        return "\n".join(clean(line) for line in text.splitlines())
    return " ".join("".join(char for char in text if char.isprintable() or char.isspace()).split())


def load_snapshot(path: Path) -> tuple[JsonObject | None, str | None]:
    """Read fresh conversations with tmux panes or return a displayable error."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        log = path.with_name("collector.log")
        if log.exists() and log.stat().st_size:
            return None, "Status collector: " + clean(
                log.read_text(encoding="utf-8").splitlines()[-1]
            )
        return None, "Connecting to Codex…"
    except (OSError, ValueError):
        return None, "Cannot read the status snapshot"
    if time.time() - data["generated_at"] > 10:
        return None, "Status snapshot is stale"
    if data["connection"]["status"] != "connected":
        return None, "Codex unavailable: " + clean(data["connection"]["error"])
    data["agents"] = [agent for agent in data["agents"] if agent["tmux_panes"]]
    return data, None


def rows(path: Path, attention: bool) -> None:
    """Print conversation rows, optionally limited to those needing attention."""
    data, error = load_snapshot(path)
    if data is None:
        print(f"-\t\033[90m{error}\033[0m")
        return
    agents = [agent for agent in data["agents"] if not attention or agent["needs_attention"]]
    if not agents:
        label = (
            "No agents need attention"
            if attention
            else "No Codex conversations open in this tmux server"
        )
        print(f"-\t\033[90m{label}\033[0m")
    for agent in agents:
        color, label = STYLES[agent["status"]]
        project = clean(agent["project"])[:14]
        title = clean(agent["title"])
        if agent["parent_id"]:
            title = "↳ " + title
        print(
            f"{agent['id']}\t\033[{color}m● {label:8s}\033[0m  \033[90m{project:14s}\033[0m {title}"
        )


def header(path: Path) -> None:
    """Print status counts and the last refresh time."""
    data, error = load_snapshot(path)
    if data is None:
        print(f"{error}\nRetrying every 2 seconds\n ")
        return
    agents = data["agents"]
    attention = sum(agent["needs_attention"] for agent in agents)
    working = sum(agent["status"] == "working" for agent in agents)
    idle = sum(agent["status"] == "idle" for agent in agents)
    stamp = time.strftime("%I:%M:%S %p", time.localtime(data["generated_at"])).lstrip("0")
    print(f"{attention} attention · {working} working · {idle} idle")
    print(f"{len(agents)} conversations in tmux · updated {stamp}\n ")


def state_message(path: Path) -> None:
    """Print a preview message when no conversation is selected."""
    _, error = load_snapshot(path)
    print(error or "No matching conversations")
    if error:
        print("\nWaiting for a fresh snapshot from the local Codex server.")


def open_thread(path: Path, thread_id: str, client: str) -> None:
    """Emit an fzf action to switch panes or explain why navigation is unavailable."""
    from .tmux import pane_matches

    if not os.environ.get("TMUX"):
        print("change-footer(Open the picker inside tmux to switch panes)")
        return
    data, _ = load_snapshot(path)
    if data is None:
        print("change-footer(Status unavailable; wait for a refresh)")
        return
    ids = [agent["id"] for agent in data["agents"]]
    panes = pane_matches(ids).get(thread_id, [])
    if not panes:
        print("change-footer(No matching tmux pane · Alt-Enter expand · Esc close)")
        return
    if len(panes) > 1:
        print("change-footer(Thread is open in multiple panes · Alt-Enter expand · Esc close)")
        return
    command = ["tmux", "switch-client", "-t", panes[0]]
    if client:
        command.extend(["-c", client])
    print("become:" + shlex.join(command))


def item_text(item: JsonObject) -> tuple[str, str] | tuple[None, None]:
    """Extract a label and display text from a conversation item."""
    kind = item.get("type")
    if kind == "agentMessage":
        return "CODEX", item.get("text", "")
    if kind == "userMessage":
        return "PROMPT", "\n".join(
            part.get("text", "") for part in item.get("content", []) if part.get("type") == "text"
        )
    if kind == "commandExecution":
        return "COMMAND", item.get("command", "")
    if kind == "mcpToolCall":
        return "TOOL", f"{item.get('server', '')} / {item.get('tool', '')}"
    return None, None


def detail() -> None:
    """Render conversation details from JSON on standard input."""
    try:
        agent = json.load(sys.stdin)
    except ValueError:
        print("Details unavailable. The conversation may have closed; retrying on refresh.")
        return
    color, label = STYLES[agent["status"]]
    print(f"{clean(agent['title'])}\n")
    print(f"\033[{color}m● {label}\033[0m\n")
    print(f"\033[90mPROJECT\033[0m  {clean(agent['project'])}")
    print(f"\033[90mPATH\033[0m     {clean(agent['cwd'])}")
    if agent.get("model"):
        print(f"\033[90mMODEL\033[0m    {clean(agent['model'])}")
    print(f"\033[90mTHREAD\033[0m   {clean(agent['id'])}")
    if agent.get("parent_id"):
        print(f"\033[90mPARENT\033[0m   {clean(agent['parent_id'])}")
    if agent["status"] == "ready":
        print("\nCodex reports an unread completed result.")
    latest = agent.get("latest_turn")
    if latest:
        print(f"\n\033[90mLATEST TURN\033[0m  {clean(latest.get('status'))}")
        if latest.get("error"):
            print(clean(latest["error"].get("message", "Turn failed"), multiline=True))
    shown = 0
    entries = agent.get("recent_items") or [
        {"item": item} for item in reversed((latest or {}).get("items", []))
    ]
    for entry in entries:
        label, text = item_text(entry.get("item", {}))
        if not text:
            continue
        print(f"\n\033[90m{label}\033[0m\n{clean(text, multiline=True)[:1800]}")
        shown += 1
        if shown == 3:
            break
    if not shown:
        if agent.get("initial_prompt"):
            print(
                f"\n\033[90mINITIAL PROMPT\033[0m\n{clean(agent['initial_prompt'], multiline=True)[:1800]}"
            )
        else:
            print("\nNo messages yet.")
    if agent.get("history_error"):
        print("\n\033[90mRecent history unavailable for this conversation.\033[0m")


def run(mode: str, snapshot: Path | None, thread_id: str | None, client: str) -> None:
    """Render a picker section or prepare pane navigation."""
    if mode == "detail":
        detail()
        return
    assert snapshot is not None
    if mode == "rows":
        deadline = time.monotonic() + 10
        while not snapshot.exists() and time.monotonic() < deadline:
            log = snapshot.with_name("collector.log")
            if log.exists() and log.stat().st_size:
                break
            time.sleep(0.02)
    if mode == "open":
        assert thread_id is not None
        open_thread(snapshot, thread_id, client)
    elif mode == "rows":
        rows(snapshot, os.environ.get("FZF_PROMPT") == "Attention › ")
    elif mode == "header":
        header(snapshot)
    else:
        state_message(snapshot)
