"""Format the dashboard using the terminal's colors."""

from itertools import groupby
from pathlib import Path

from prompt_toolkit.formatted_text import StyleAndTextTuples
from prompt_toolkit.styles import Style
from prompt_toolkit.utils import get_cwidth

from tmux_codex_status.status import AgentState, JsonObject

LABELS: dict[AgentState, str] = {
    "approval": "Approval",
    "input": "Needs input",
    "ready": "Ready",
    "working": "Working",
    "idle": "Idle",
    "error": "Error",
    "unknown": "Unknown",
}
STYLE = Style.from_dict(
    {
        "": "fg:default bg:default nobold",
        "title": "fg:ansiyellow",
        "muted": "fg:ansibrightblack",
        "selected": "bg:#3a3a3a noreverse",
        "tab": "bg:#3a3a3a fg:ansiyellow",
        "approval": "fg:ansired",
        "input": "fg:ansired",
        "ready": "fg:ansigreen",
        "working": "fg:ansicyan",
        "idle": "fg:ansibrightblack",
        "error": "fg:ansimagenta",
        "unknown": "fg:ansibrightblack",
    }
)


def clean(value: object, multiline: bool = False) -> str:
    """Remove terminal control characters from external text."""
    text = str(value or "")
    if multiline:
        return "\n".join(clean(line) for line in text.splitlines())
    return " ".join("".join(char for char in text if char.isprintable() or char.isspace()).split())


def fit(text: str, width: int) -> str:
    """Pad or truncate text to a number of terminal cells."""
    width = max(0, width)
    if get_cwidth(text) <= width:
        return text + " " * (width - get_cwidth(text))
    result = ""
    for char in text:
        if get_cwidth(result + char) > width - 1:
            break
        result += char
    return result + ("…" if width else "") + " " * max(0, width - get_cwidth(result) - 1)


def path_label(path: str) -> str:
    """Abbreviate the home directory in project headings."""
    home = str(Path.home())
    return clean("~" + path[len(home) :] if path == home or path.startswith(home + "/") else path)


def clip_line(fragments: StyleAndTextTuples, width: int) -> StyleAndTextTuples:
    """Clip a styled line to the available terminal cells."""
    result: StyleAndTextTuples = []
    for fragment in fragments:
        style, text = fragment[:2]
        if get_cwidth(text) > width:
            result.append((style, fit(text, width)))
            break
        result.append((style, text))
        width -= get_cwidth(text)
    return result


def task_lines(
    agents: list[JsonObject], selected: str | None, width: int
) -> tuple[list[StyleAndTextTuples], int]:
    """Build project headings and selectable task rows."""
    lines: list[StyleAndTextTuples] = []
    cursor = 0
    for cwd, entries in groupby(agents, key=lambda agent: agent["cwd"]):
        group = list(entries)
        if lines:
            lines.append([])
        lines.append([("class:muted", fit(f"{path_label(cwd)}  {len(group)}", width))])
        for agent in group:
            active = agent["id"] == selected
            if active:
                cursor = len(lines)
            base = "class:selected" if active else ""
            status = agent["status"]
            title = clean(agent["title"])
            if agent.get("parent_id"):
                title = "↳ " + title
            label_width = 13 if width >= 40 else 0
            row: StyleAndTextTuples = [
                (f"{base} class:title", "› " if active else "  "),
                (f"{base} class:{status}", "○ " if status == "idle" else "● "),
                (base, fit(title, width - label_width - 4)),
            ]
            if label_width:
                row.append((f"{base} class:{status}", fit("  " + LABELS[status], label_width)))
            lines.append(row)
    return lines, cursor


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


def wrap(text: str, width: int) -> list[str]:
    """Wrap text at spaces without exceeding the terminal width."""
    width = max(1, width)
    lines: list[str] = []
    for paragraph in text.split("\n"):
        remaining = paragraph
        while get_cwidth(remaining) > width:
            end = 0
            cells = 0
            for char in remaining:
                cells += get_cwidth(char)
                if cells > width:
                    break
                end += 1
            end = max(1, end)
            space = remaining.rfind(" ", 0, end + 1)
            if space > 0:
                end = space
            lines.append(remaining[:end])
            remaining = remaining[end:].lstrip()
        lines.append(remaining)
    return lines


def detail_lines(
    agent: JsonObject | None, details: JsonObject, width: int
) -> list[StyleAndTextTuples]:
    """Format metadata and recent messages for the details pane."""
    if agent is None:
        return [[("class:muted", "No conversation selected")]]
    blocks: list[tuple[str, str]] = [
        ("", clean(agent["title"])),
        (f"class:{agent['status']}", "● " + LABELS[agent["status"]]),
        ("", ""),
        ("class:muted", "Project"),
        ("", path_label(agent["cwd"])),
    ]
    if agent.get("model"):
        blocks.extend([("", ""), ("class:muted", "Model"), ("", clean(agent["model"]))])
    blocks.extend([("", ""), ("class:muted", "Thread"), ("", clean(agent["id"]))])
    if agent["status"] == "ready":
        blocks.extend([("", ""), ("class:ready", "Completed result waiting to be read.")])
    if agent["error"]:
        blocks.extend([("", ""), ("class:error", clean(agent["error"]))])
    latest = details.get("latest_turn") or {}
    if latest.get("error"):
        blocks.extend([("", ""), ("class:error", clean(latest["error"].get("message")))])
    entries = details.get("recent_items") or [
        {"item": item} for item in reversed(latest.get("items", []))
    ]
    shown = 0
    for entry in entries:
        label, text = item_text(entry.get("item", {}))
        if text:
            blocks.extend([("", ""), ("class:title", label), ("", clean(text, True)[:6000])])
            shown += 1
        if shown == 3:
            break
    if not shown:
        message = details.get("initial_prompt")
        blocks.extend(
            [
                ("", ""),
                ("class:muted", "Prompt" if message else "Recent activity"),
                ("", clean(message, True) if message else "No messages yet."),
            ]
        )
    if details.get("history_error"):
        blocks.extend([("", ""), ("class:error", clean(details["history_error"]))])
    return [[(style, line)] for style, text in blocks for line in wrap(text, width)]
