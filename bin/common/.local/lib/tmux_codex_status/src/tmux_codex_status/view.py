"""Format conversation data with the terminal's palette."""

from itertools import groupby, islice
from pathlib import Path

from rich.table import Table
from rich.text import Text
from textual.widgets.option_list import Option

from tmux_codex_status.status import AgentState, JsonObject

STYLES: dict[AgentState, tuple[str, str]] = {
    "approval": ("red", "Approval"),
    "input": ("red", "Needs input"),
    "ready": ("green", "Ready"),
    "working": ("cyan", "Working"),
    "idle": ("bright_black", "Idle"),
    "error": ("magenta", "Error"),
    "unknown": ("bright_black", "Unknown"),
}


def clean(value: object) -> str:
    """Remove terminal controls while preserving whitespace in messages."""
    return "".join(char for char in str(value or "") if char.isprintable() or char in "\n\t")


def path_label(path: str) -> str:
    """Abbreviate the home directory in project headings."""
    home = str(Path.home())
    return clean("~" + path[len(home) :] if path == home or path.startswith(home + "/") else path)


def task_options(agents: list[JsonObject]) -> list[Option]:
    """Group selectable tasks under disabled project headings."""
    options: list[Option] = []
    for cwd, entries in groupby(agents, key=lambda agent: agent["cwd"]):
        group = list(entries)
        heading = Text(f"{'\n' if options else ''}{path_label(cwd)}  {len(group)}", "bright_black")
        options.append(Option(heading, id=f"project:{cwd}", disabled=True))
        for agent in group:
            color, label = STYLES[agent["status"]]
            row = Table.grid(expand=True, padding=(0, 1))
            row.add_column(width=1)
            row.add_column(ratio=1, no_wrap=True, overflow="ellipsis")
            row.add_column(width=11, no_wrap=True)
            title = ("↳ " if agent.get("parent_id") else "") + " ".join(
                clean(agent["title"]).split()
            )
            row.add_row(
                Text("○" if agent["status"] == "idle" else "●", color),
                Text(title),
                Text(label, color),
            )
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
    """Build metadata and recent activity, leaving wrapping to the widget."""
    if agent is None:
        return Text("No conversation selected", "bright_black")
    color, label = STYLES[agent["status"]]
    text = Text(clean(agent["title"]) + "\n")
    text.append(f"● {label}\n", color)
    for label, value in (
        ("Project", path_label(agent["cwd"])),
        ("Model", agent.get("model")),
        ("Thread", agent["id"]),
    ):
        if value:
            text.append(f"\n{label}\n", "bright_black")
            text.append(clean(value) + "\n")
    if agent["status"] == "ready":
        text.append("\nCompleted result waiting to be read.\n", "green")
    latest = details.get("latest_turn") or {}
    entries = details.get("recent_items") or [
        {"item": item} for item in reversed(latest.get("items", []))
    ]
    messages = (item_text(entry.get("item", {})) for entry in entries)
    messages = list(islice(((label, body) for label, body in messages if body), 3))
    if not messages:
        messages = [("Prompt", details.get("initial_prompt") or "No messages yet.")]
    for label, body in messages:
        text.append(f"\n{label}\n", "yellow")
        text.append(clean(body)[:6000] + "\n")
    for error in (
        agent.get("error"),
        (latest.get("error") or {}).get("message"),
        details.get("history_error"),
    ):
        if error:
            text.append("\n" + clean(error), "magenta")
    return text
