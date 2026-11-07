# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Render codex-status JSON for the terminal picker."""

import argparse
import json
import os
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
    return " ".join(
        "".join(char for char in text if char.isprintable() or char.isspace()).split()
    )


def load_snapshot(path: Path) -> tuple[JsonObject | None, str | None]:
    """Read a fresh snapshot or return a displayable error."""
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
    return data, None


def rows(path: Path, attention: bool) -> None:
    """Print conversation rows, optionally limited to those needing attention."""
    data, error = load_snapshot(path)
    if data is None:
        print(f"-\t\033[90m{error}\033[0m")
        return
    agents = [
        agent for agent in data["agents"] if not attention or agent["needs_attention"]
    ]
    if not agents:
        label = (
            "No agents need attention"
            if attention
            else "No conversations loaded in Codex"
        )
        print(f"-\t\033[90m{label}\033[0m")
    for agent in agents:
        color, label = STYLES[agent["status"]]
        project = clean(agent["project"])[:14]
        title = clean(agent["title"])
        if agent["parent_id"]:
            title = "↳ " + title
        print(
            f"{agent['id']}\t\033[{color}m● {label:8s}\033[0m  "
            f"\033[90m{project:14s}\033[0m {title}"
        )


def header(path: Path) -> None:
    """Print status counts and the last refresh time."""
    data, error = load_snapshot(path)
    if data is None:
        print(f"{error}\nRetrying every 2 seconds\n ")
        return
    counts = data["counts"]
    stamp = time.strftime("%I:%M:%S %p", time.localtime(data["generated_at"])).lstrip(
        "0"
    )
    print(
        f"{counts['attention']} attention · {counts['working']} working · {counts['idle']} idle"
    )
    print(f"{counts['total']} loaded conversations · updated {stamp}\n ")


def state_message(path: Path) -> None:
    """Print a preview message when no conversation is selected."""
    _, error = load_snapshot(path)
    print(error or "No matching conversations")
    if error:
        print("\nWaiting for a fresh snapshot from the local Codex server.")


def item_text(item: JsonObject) -> tuple[str, str] | tuple[None, None]:
    """Extract a label and display text from a conversation item."""
    kind = item.get("type")
    if kind == "agentMessage":
        return "CODEX", item.get("text", "")
    if kind == "userMessage":
        return "PROMPT", "\n".join(
            part.get("text", "")
            for part in item.get("content", [])
            if part.get("type") == "text"
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
        print(
            "Details unavailable. The conversation may have closed; retrying on refresh."
        )
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


def main() -> None:
    """Render the requested picker section."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("rows", "header", "message", "detail"))
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--wait", action="store_true")
    args = parser.parse_args()
    if args.wait:
        deadline = time.monotonic() + 1
        while not args.snapshot.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
    if args.mode == "detail":
        detail()
    elif args.mode == "rows":
        rows(args.snapshot, os.environ.get("FZF_PROMPT") == "Attention › ")
    elif args.mode == "header":
        header(args.snapshot)
    else:
        state_message(args.snapshot)


if __name__ == "__main__":
    main()
