"""Open the Codex picker, render fzf content, or export status as JSON."""

from pathlib import Path

import click
from websockets.exceptions import WebSocketException

from tmux_codex_status import render, status


@click.group(
    invoke_without_command=True,
    context_settings={"help_option_names": ["-h", "--help"]},
)
@click.option("--json", "as_json", is_flag=True, help="Print one status snapshot")
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
@click.option("--client", default="", hidden=True)
@click.pass_context
def cli(
    context: click.Context,
    as_json: bool,
    watch: bool,
    interval: float,
    output: Path | None,
    detail: str | None,
    client: str,
) -> None:
    """Dispatch the picker, fzf rendering, or JSON status output."""
    if detail and watch:
        raise click.UsageError("--detail cannot be combined with --watch")
    if context.invoked_subcommand is not None:
        return
    try:
        if as_json or watch or output or detail:
            try:
                status.run(watch, interval, output, detail)
            except (WebSocketException, status.RpcError) as exc:
                raise click.ClickException(str(exc)) from exc
        else:
            from . import picker

            picker.run(client)
    except BrokenPipeError:
        return
    except (OSError, ValueError) as exc:
        raise click.ClickException(str(exc)) from exc


@cli.command("render")
@click.argument(
    "mode", type=click.Choice(("rows", "header", "message", "detail", "open"))
)
@click.option("--snapshot", type=click.Path(path_type=Path))
@click.option("--thread")
@click.option("--client", default="")
def render_command(
    mode: str, snapshot: Path | None, thread: str | None, client: str
) -> None:
    """Render content for fzf."""

    if mode != "detail" and snapshot is None:
        raise click.UsageError("--snapshot is required")
    if mode == "open" and thread is None:
        raise click.UsageError("--thread is required")
    try:
        render.run(mode, snapshot, thread, client)
    except BrokenPipeError:
        return
    except (OSError, ValueError) as exc:
        raise click.ClickException(str(exc)) from exc
