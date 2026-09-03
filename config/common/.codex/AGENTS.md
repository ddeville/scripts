# Global Agent Instructions

## Scope and Priority

- These instructions are global defaults for all repositories.
- If a repository has its own `AGENTS.md`, treat repository-local instructions as higher priority within that repository.

## Command Safety

- Do not run destructive commands unless explicitly requested.
- Treat `git reset --hard`, `git checkout -- <path>`, and broad `rm -rf` operations as destructive.
- Prefer non-interactive commands over interactive workflows.

## Git Behavior

- When executing Git commands during agent work, disable fsmonitor for each command to avoid spawning persistent fsmonitor daemons.
- Use: `git -c core.fsmonitor=false <subcommand> ...`
- Git commands written for the user in scripts, source code, or documentation must not include fsmonitor overrides.
- Do not change the user's global or repository fsmonitor configuration unless explicitly asked.
- Do not commit or push unless explicitly requested.
- Do not amend existing commits unless explicitly requested.
- Do not merge PRs or use administrative overrides (such as `gh pr merge --admin`) unless explicitly requested. This applies to all CLIs, connectors, APIs, and UIs.

## Editing Style

- Keep changes minimal and surgical.
- Preserve existing style and patterns.
- Avoid unrelated refactors.
- Avoid unnecessary comments that only describe chain-of-thought or add no useful context for humans maintaining the code.
- Avoid overly defensive programming (e.g., exhaustive catch-all handling and branch coverage) unless explicitly requested.

## Test Quality

- Value tests that provide meaningful confidence in behavior and protect against regressions; test quality matters more than quantity.
- Do not add tests merely for the sake of having tests or increasing coverage numbers.
- Tests are code. Write and structure them with the same care as production logic, keeping them clear, focused, and maintainable.

## Validation

- Run the smallest useful validation for the changed scope first.
- Prefer targeted checks over full-suite runs unless the user asks for broader validation.
- Report what was validated and what was not validated.

## Communication

- Provide short progress updates during multi-step work.
- For changes, keep the final response proportional to the task: summarize what changed, identify modified files, and report relevant validation.
- Mention residual risks, limitations, or follow-up suggestions only when material.
- Ask for clarification when ambiguity materially affects correctness, scope, or risk; otherwise state a reasonable assumption and continue.
- Reuse authorization already given in the conversation; do not ask for it again unless the scope or risk materially changes.
- If task scope expands materially beyond the original request, call it out and confirm before proceeding.

## Solution Bias

- Prefer simpler solutions and lower complexity by default unless there is a clear, measurable need for additional complexity.

## Environment Conventions

- Prefer `rg` / `rg --files` for searching.
- Prefer `apply_patch` for focused file edits.
- Avoid scripting (e.g., Python) for simple read/write changes when shell tools suffice.
