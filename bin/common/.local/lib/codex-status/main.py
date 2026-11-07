# /// script
# requires-python = ">=3.12"
# dependencies = ["websockets==15.0.1"]
# ///
"""Open the Codex picker or export conversation status as JSON."""

import argparse
import sys
from pathlib import Path


def main() -> None:
    """Choose the interactive picker or a JSON status output."""
    parser = argparse.ArgumentParser(prog="codex-status", description=__doc__)
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
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("--interval must be positive")
    if args.detail and args.watch:
        parser.error("--detail cannot be combined with --watch")
    if args.json or args.watch or args.output or args.detail:
        import status
        from websockets.exceptions import WebSocketException

        try:
            status.run(args.watch, args.interval, args.output, args.detail)
        except (WebSocketException, status.RpcError) as exc:
            parser.exit(1, f"codex-status: {exc}\n")
    else:
        import picker

        picker.run(args.client)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    except (OSError, ValueError) as exc:
        print(f"codex-status: {exc}", file=sys.stderr)
        sys.exit(1)
