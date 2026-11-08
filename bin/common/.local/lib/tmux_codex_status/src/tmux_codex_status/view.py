"""Format conversation data with the terminal's palette."""

from collections import Counter
from pathlib import Path

from rich.table import Table
from rich.text import Text
from textual.widgets.option_list import Option

from tmux_codex_status.status import AgentState, JsonObject

STYLES: dict[AgentState, tuple[str, str]] = {
    "approval": ("red", "Approve"),
    "input": ("red", "Reply"),
    "ready": ("green", "Read result"),
    "working": ("cyan", "Working"),
    "idle": ("bright_black", "Idle"),
    "error": ("magenta", "Check error"),
    "unknown": ("bright_black", "Check status"),
}
ACTION_HINTS = {
    "approval": "Waiting for approval. Open the agent to approve or reject the request.",
    "input": "Waiting for your answer. Open the agent to reply.",
    "ready": "A completed result is waiting to be read.",
    "error": "The agent reported an error. Open it to investigate.",
    "working": "Working. Open the agent to follow progress or steer it.",
    "idle": "Idle. Open the agent to continue the conversation.",
    "unknown": "Status is unknown. Open the agent to check.",
}


def clean(value: object) -> str:
    """Remove terminal controls while preserving whitespace in messages."""
    return "".join(char for char in str(value or "") if char.isprintable() or char in "\n\t")


def path_label(path: str) -> str:
    """Abbreviate the home directory in project headings."""
    home = str(Path.home())
    if path == home or path.startswith(home + "/"):
        path = "~" + path[len(home) :]
    return clean(path)


def attention_summary(agents: list[JsonObject]) -> Text:
    """Distinguish blocked agents, errors, and unread results at a glance."""
    counts = Counter(agent["status"] for agent in agents)
    parts = [
        Text(f"{label} {counts[state]}", STYLES[state][0])
        for state, label in (
            ("approval", "Approve"),
            ("input", "Reply"),
            ("error", "Errors"),
            ("ready", "Unread"),
        )
        if counts[state]
    ]
    if not parts:
        return Text("Nothing needs your attention", "bright_black")
    return Text("Needs you:  ") + Text("  ·  ", "bright_black").join(parts)


def task_options(agents: list[JsonObject], positions: dict[str, int]) -> list[Option]:
    """Show stable jump keys, task titles, projects, and explicit next actions."""
    options: list[Option] = []
    for agent in agents:
        color, label = STYLES[agent["status"]]
        position = positions[agent["id"]]
        shortcut = str((position + 1) % 10) if position < 10 else ""
        row = Table.grid(expand=True, padding=(0, 1))
        row.add_column(width=1)
        row.add_column(width=1)
        row.add_column(ratio=1, no_wrap=True, overflow="ellipsis")
        row.add_column(width=12, no_wrap=True)
        title = " ".join(clean(agent["title"]).split())
        if agent.get("parent_id"):
            title = "↳ " + title
        row.add_row(
            Text(shortcut, "yellow"),
            Text("○" if agent["status"] == "idle" else "●", color),
            Text(title),
            Text(label, color),
        )
        row.add_row("", "", Text(path_label(agent["cwd"]), "bright_black"), "")
        options.append(Option(row, id=agent["id"]))
    return options


def item_text(item: JsonObject) -> tuple[str, str]:
    """Extract the useful text from a conversation item."""
    match item.get("type"):
        case "agentMessage":
            return "Codex", item.get("text", "")
        case "userMessage":
            return "Prompt", "\n".join(
                part.get("text", "")
                for part in item.get("content", [])
                if part.get("type") == "text"
            )
        case "commandExecution":
            return "Command", item.get("command", "")
        case "mcpToolCall":
            return "Tool", f"{item.get('server', '')} / {item.get('tool', '')}"
        case _:
            return "", ""


def detail_text(agent: JsonObject | None, details: JsonObject) -> Text:
    """Lead with the next action, then show errors and recent activity."""
    if agent is None:
        return Text("No conversation selected", "bright_black")
    color, _ = STYLES[agent["status"]]
    text = Text(clean(agent["title"]) + "\n")
    text.append(path_label(agent["cwd"]) + "\n", "bright_black")
    text.append("\n" + ACTION_HINTS[agent["status"]] + "\n", color)
    text.append("Enter to open\n", "bright_black")
    latest = details.get("latest_turn") or {}
    for error in (
        agent.get("error"),
        (latest.get("error") or {}).get("message"),
        details.get("history_error"),
    ):
        if error:
            text.append("\n" + clean(error) + "\n", "magenta")
    entries = details.get("recent_items") or [
        {"item": item} for item in reversed(latest.get("items", []))
    ]
    messages: list[tuple[str, str]] = []
    for entry in entries:
        label, body = item_text(entry.get("item", {}))
        if body:
            messages.append((label, body))
        if len(messages) == 3:
            break
    if not messages:
        placeholder = "No messages yet." if details else "Loading recent activity…"
        messages = [("Prompt", details.get("initial_prompt") or placeholder)]
    for label, body in messages:
        text.append(f"\n{label}\n", "yellow")
        text.append(clean(body)[:6000] + "\n")
    return text
