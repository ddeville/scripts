"""Match Codex conversations to their current tmux panes."""

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
        pane, _, remainder = line.partition("\t")
        command, _, title = remainder.partition("\t")
        suffix = title.rsplit(" | ", 1)[-1]
        if command != "codex" or not TITLE_ID.fullmatch(suffix):
            continue
        prefix = suffix.removesuffix("...")
        candidates = [
            thread_id for thread_id in thread_ids if thread_id.startswith(prefix)
        ]
        if len(candidates) == 1:
            matches.setdefault(candidates[0], []).append(pane)
    return matches
