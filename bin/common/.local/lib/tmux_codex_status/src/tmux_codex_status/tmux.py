"""Match Codex conversations to their current tmux panes."""

import os
import re
import subprocess

TITLE_ID = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-"
    r"(?:[0-9a-f]{12}|[0-9a-f]{5}\.\.\.)"
)


def pane_matches(thread_ids: list[str]) -> dict[str, list[str]]:
    """Resolve trailing title IDs to threads, ignoring ambiguous prefixes."""
    try:
        result = subprocess.run(
            [
                "tmux",
                "list-panes",
                "-a",
                "-F",
                "#{pane_id}\t#{pane_current_command}\t#{pane_title}",
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return {}

    matches: dict[str, list[str]] = {}
    for line in result.stdout.splitlines():
        pane_id, _, remainder = line.partition("\t")
        command, _, title = remainder.partition("\t")
        suffix = title.rsplit(" | ", 1)[-1]
        if command != "codex" or not TITLE_ID.fullmatch(suffix):
            continue
        prefix = suffix.removesuffix("...")
        candidates = [thread_id for thread_id in thread_ids if thread_id.startswith(prefix)]
        if len(candidates) == 1:
            matches.setdefault(candidates[0], []).append(pane_id)
    return matches


def switch_command(thread_id: str, thread_ids: list[str], client: str) -> list[str]:
    """Find a unique live pane and build the command to open it."""
    if not os.environ.get("TMUX"):
        raise ValueError("Open the picker inside tmux to switch panes")
    panes = pane_matches(thread_ids).get(thread_id, [])
    if not panes:
        raise ValueError("No matching tmux pane; the conversation may have closed")
    if len(panes) > 1:
        raise ValueError("This conversation is open in multiple panes")
    command = ["tmux", "switch-client", "-t", panes[0]]
    if client:
        command.extend(["-c", client])
    return command
