"""Run the fzf picker and its background status collector."""

import os
import shlex
import signal
import subprocess
import tempfile
from pathlib import Path
from types import FrameType
from typing import NoReturn


def terminate(signum: int, frame: FrameType | None) -> NoReturn:
    """Exit through cleanup when the picker receives a termination signal."""
    raise SystemExit(128 + signum)


def run(client: str) -> None:
    """Keep a status snapshot fresh while fzf displays and selects conversations."""
    signal.signal(signal.SIGTERM, terminate)
    command = ["tmux_codex_status"]
    with tempfile.TemporaryDirectory(prefix="tmux-codex-status-") as temporary:
        runtime = Path(temporary)
        snapshot = runtime / "state.json"
        render = shlex.join([*command, "render", "--snapshot", str(snapshot)])
        status = shlex.join([*command, "status"])
        preview = (
            f"if [[ {{1}} == - ]]; then {render} message; "
            f"else {status} --detail {{1}} 2>/dev/null | {render} detail; fi"
        )
        toggle = """if [[ $FZF_PROMPT == 'All agents › ' ]]; then
  echo 'change-prompt(Attention › )'
else
  echo 'change-prompt(All agents › )'
fi"""
        preview_layout = "right,44%,wrap,border-left,<42(down,55%,border-top)"
        options = [
            "fzf",
            "--ansi",
            "--delimiter=\t",
            "--with-nth=2..",
            "--track",
            "--id-nth=1",
            "--no-sort",
            "--layout=reverse",
            "--no-multi",
            "--no-hscroll",
            "--border=rounded",
            "--border-label= CODEX AGENTS ",
            "--padding=1",
            "--info=inline-right",
            "--highlight-line",
            "--no-bold",
            "--color=base16,fg:-1,bg:-1,hl:3,fg+:-1,bg+:237,hl+:3,query:-1,info:8,prompt:3,pointer:3,marker:3,spinner:3,border:8,header:8,footer:8,label:3,gutter:-1,preview-fg:-1,preview-bg:-1",
            "--prompt=All agents › ",
            "--pointer=▌",
            "--header=Connecting to Codex…\nRefreshing every 2 seconds\n ",
            "--footer=Enter open · Alt-Enter expand · Ctrl-f attention · Ctrl-/ details\n↑↓ move · Alt-j/k scroll details · Esc close",
            f"--preview={preview}",
            f"--preview-window={preview_layout}",
            "--with-shell=bash -c",
            f"--bind=start:reload-sync({render} rows)",
            f"--bind=every(2):reload-sync({render} rows)",
            f"--bind=load:bg-transform-header({render} header)+refresh-preview",
            f"--bind=ctrl-f:transform({toggle})+reload-sync({render} rows)",
            f"--bind=enter:bg-transform({render} open --client {shlex.quote(client)} --thread {{1}})",
            f"--bind=alt-enter:change-preview-window(down,99%,wrap,border-none|{preview_layout})",
            "--bind=ctrl-/:toggle-preview,alt-j:preview-down,alt-k:preview-up",
        ]
        with (runtime / "collector.log").open("w", encoding="utf-8") as log:
            collector = subprocess.Popen(
                [*command, "status", "--watch", "--output", str(snapshot)],
                stdout=log,
                stderr=subprocess.STDOUT,
            )
            try:
                result = subprocess.run(
                    options,
                    check=False,
                    stdin=subprocess.DEVNULL,
                    env={
                        **os.environ,
                        "FZF_DEFAULT_OPTS": "",
                        "FZF_DEFAULT_OPTS_FILE": "",
                    },
                )
            finally:
                collector.terminate()
                collector.wait()
        if result.returncode not in (0, 1, 130):
            raise SystemExit(result.returncode)
