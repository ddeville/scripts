# Repository Guidelines

## Project Structure & Module Organization
This repository is a personal environment/tooling monorepo managed with stow-style paths.

- `config/common/`: shared dotfiles (`.config/nvim`, fish, git, tmux, etc.).
- `config/macos/` and `config/linux/`: platform-specific overrides.
- `bin/common/.local/bin/`: cross-platform helper scripts.
- `bin/macos/.local/bin/` and `bin/linux/.local/bin/`: OS-specific utilities.
- `install/`: install entrypoints and package setup (`arch/`, `macos/`, `devbox/`, `Makefile`).
- `.github/workflows/`: CI for linters and secret scanning.

## Build, Test, and Development Commands
- `make -C install install`: run full platform install (`install/arch/install.sh` or `install/macos/install.sh`).
- `make -C install packages`: install/update packages for current OS.
- `make -C install stow`: apply symlinked config changes.
- `make -C install shell-plugins`: refresh shell plugin dependencies.

Useful local lint checks (matching CI intent):
- `stylua --check config/common/.config/nvim`
- `shfmt --simplify --indent 2 -d <files>`
- `shellcheck <script.sh>`

## Coding Style & Naming Conventions
- Shell scripts should be POSIX/Bash-friendly, executable, and lint-clean.
- Keep shell formatting consistent with CI (`shfmt` indent `2`, simplify enabled).
- Lua style follows `.stylua.toml`; avoid ad-hoc style changes.
- Prefer descriptive script names (`nodeswitch`, `update-shell-plugins`) over abbreviations.

## Testing Guidelines
There is no unit-test suite; quality is enforced mainly via linters and manual validation.

- Run targeted linting for edited files before opening a PR.
- Validate behavior changes by running the relevant command locally (for example, run updated scripts directly).
- Ensure no secrets are introduced; CI runs `detect-secrets`.

## Commit & Push Guidelines
- Follow the existing commit style: short, imperative, scoped summaries (for example, `Add codex config`, `Fix gitignore`).
- Keep commits focused; avoid bundling unrelated changes.
- Before pushing, sanity-check changed paths and run targeted validation for touched files.
- If a change is non-trivial, include brief rationale in the commit body (what changed and why).

## Security & Configuration Tips
- Never commit credentials, tokens, or machine-specific secrets.
- Keep personal/local runtime state out of the repo unless intentionally tracked.
