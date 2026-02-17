# Global Agent Instructions

## Scope and Priority

- These instructions are global defaults for all repositories.
- If a repository has its own `AGENTS.md`, treat repository-local instructions as higher priority within that repository.

## Command Safety

- Do not run destructive commands unless explicitly requested.
- Treat `git reset --hard`, `git checkout -- <path>`, and broad `rm -rf` operations as destructive.
- Prefer non-interactive commands over interactive workflows.

## Git Behavior

- When running Git commands, disable fsmonitor for that command to avoid spawning persistent fsmonitor daemons from agent activity.
- Use: `git -c core.fsmonitor=false <subcommand> ...`
- Do not change the user's global or repository fsmonitor configuration unless explicitly asked.
- Do not commit or push unless explicitly requested.
- Do not amend existing commits unless explicitly requested.
- When using the gh tool do not under any condition merge a PR (or use the --admin option) unless specifically requested.

## Editing Style

- Keep changes minimal and surgical.
- Preserve existing style and patterns.
- Avoid unrelated refactors.
- Avoid unnecessary comments that only describe chain-of-thought or add no useful context for humans maintaining the code.
- Avoid overly defensive programming (e.g., exhaustive catch-all handling and branch coverage) unless explicitly requested.

## Validation

- Run the smallest useful validation for the changed scope first.
- Prefer targeted checks over full-suite runs unless the user asks for broader validation.
- Report what was validated and what was not validated.

## Communication

- Provide short progress updates during multi-step work.
- In the final response, summarize what changed.
- In the final response, list which files were modified.
- In the final response, state what validation was run.
- In the final response, note residual risks or follow-up suggestions.

## Environment Conventions

- Prefer `rg` / `rg --files` for searching.
- Prefer `apply_patch` for focused file edits.
- Avoid scripting (e.g., Python) for simple read/write changes when shell tools suffice.
