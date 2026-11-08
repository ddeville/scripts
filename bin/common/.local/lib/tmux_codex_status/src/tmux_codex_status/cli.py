"""Open the Codex picker or export status as JSON."""

from pathlib import Path

import click
from websockets.exceptions import WebSocketException

from tmux_codex_status import picker, status


@click.group(context_settings={"help_option_names": ["-h", "--help"]})
def cli() -> None:
    """Browse Codex conversations in tmux or export their status."""


@cli.command("picker")
@click.option("--client", default="", hidden=True)
def picker_command(client: str) -> None:
    """Open the interactive conversation picker."""
    try:
        picker.run(client)
    except BrokenPipeError:
        return
    except (OSError, ValueError) as exc:
        raise click.ClickException(str(exc)) from exc


@cli.command("status")
@click.option("--watch", is_flag=True, help="Stream status snapshots")
@click.option(
    "--interval",
    type=click.FloatRange(min=0, min_open=True),
    default=2,
    show_default=True,
    help="Polling interval in seconds",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Atomically write JSON to this file",
)
@click.option("--detail", metavar="THREAD_ID", help="Print conversation details")
def status_command(watch: bool, interval: float, output: Path | None, detail: str | None) -> None:
    """Output status as JSON, optionally watching for updates."""
    if detail and watch:
        raise click.UsageError("--detail cannot be combined with --watch")
    try:
        status.run(watch, interval, output, detail)
    except BrokenPipeError:
        return
    except (OSError, ValueError, WebSocketException, status.RpcError) as exc:
        raise click.ClickException(str(exc)) from exc
