# /// script
# requires-python = ">=3.12"
# dependencies = ["tomlkit==0.13.3"]
# ///
"""Apply shared Codex settings over the local config."""

import os
from collections.abc import Mapping, MutableMapping
from pathlib import Path
from typing import Any

import tomlkit


def merge(config: MutableMapping[str, Any], shared: Mapping[str, Any]) -> None:
    """Merge tables recursively and replace other shared values."""
    for key, value in shared.items():
        existing = config.get(key)
        if isinstance(existing, MutableMapping) and isinstance(value, Mapping):
            merge(existing, value)
        else:
            config[key] = value


def main() -> None:
    """Update the local config using the shared TOML file."""
    shared_path = Path(__file__).resolve().parents[1] / "config.shared.toml"
    config_path = (
        Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser() / "config.toml"
    )
    shared = tomlkit.parse(shared_path.read_text(encoding="utf-8"))
    original = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
    config = tomlkit.parse(original)
    merge(config, shared)
    updated = tomlkit.dumps(config)
    if updated != original:
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
