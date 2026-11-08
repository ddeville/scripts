"""Open the Codex picker, render fzf content, or export status as JSON."""

import argparse
import sys
from pathlib import Path


def run() -> None:
    """Dispatch the picker, fzf rendering, or JSON status output."""
    parser = argparse.ArgumentParser(prog="tmux-codex-status", description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print one status snapshot")
    parser.add_argument("--watch", action="store_true", help="Stream status snapshots")
    parser.add_argument(
        "--interval",
        type=float,
        default=2,
        help="Polling interval in seconds (default: 2)",
    )
    parser.add_argument(
        "--output", type=Path, help="Atomically write JSON to this file"
    )
    parser.add_argument(
        "--detail", metavar="THREAD_ID", help="Print conversation details"
    )
    parser.add_argument("--client", default="", help=argparse.SUPPRESS)
    commands = parser.add_subparsers(dest="command")
    renderer = commands.add_parser("render", help="Render content for fzf")
    renderer.add_argument(
        "mode", choices=("rows", "header", "message", "detail", "open")
    )
    renderer.add_argument("--snapshot", type=Path)
    renderer.add_argument("--thread")
    renderer.add_argument("--client", default="")
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("--interval must be positive")
    if args.detail and args.watch:
        parser.error("--detail cannot be combined with --watch")
    if args.command == "render":
        from . import render

        if args.mode != "detail" and args.snapshot is None:
            renderer.error("--snapshot is required")
        if args.mode == "open" and args.thread is None:
            renderer.error("--thread is required")
        render.run(args.mode, args.snapshot, args.thread, args.client)
    elif args.json or args.watch or args.output or args.detail:
        from websockets.exceptions import WebSocketException

        from . import status

        try:
            status.run(args.watch, args.interval, args.output, args.detail)
        except (WebSocketException, status.RpcError) as exc:
            parser.exit(1, f"tmux-codex-status: {exc}\n")
    else:
        from . import picker

        picker.run(args.client)


def main() -> None:
    """Run the command and report errors."""
    try:
        run()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    except (OSError, ValueError) as exc:
        print(f"tmux-codex-status: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
