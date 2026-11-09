---
name: cwt
description: Create a user-managed Git worktree and tmux session using cwt, forking the current Codex thread by default. Use when the user asks to use cwt, create a named cwt session, or fork this conversation into a worktree.
---

# Fork into a worktree

Use the installed `cwt` helper to create the worktree, branch, and tmux session.
It owns the paths and naming conventions; do not recreate that logic or use
Codex-managed worktrees.

**Fork the current thread by default.** A request to create a named `cwt` session
or worktree implies `--fork-current`, even when the user does not say "fork".
Omitting the flag opens a thread picker; use that only when explicitly requested.

For a request such as `$cwt my-feature`, run this from the current repository:

```sh
cwt --fork-current --base HEAD -- my-feature
```

For "create a new session named bootstrap off master":

```sh
cwt --fork-current --base master -- bootstrap
```

- Use the supplied feature name. If none is provided and the intended name is
  unclear, ask for it. Quote names when constructing shell commands.
- `--fork-current` reads `CODEX_THREAD_ID` from the command environment. If it is
  missing, report that instead of guessing a thread, using `--last`, or opening a
  picker. If the user explicitly supplies a different thread ID, use
  `cwt --fork "$thread_id" --base HEAD -- "$feature_name"` instead.
- Default to `--base HEAD`; replace it with an explicitly requested base.
  A dirty source worktree does not require confirmation: leave staged, unstaged,
  and untracked changes in the original worktree without copying, committing,
  stashing, or discarding them. If the source is dirty, briefly note that the new
  worktree starts from the selected commit and excludes uncommitted changes.
- Keep the default tmux and Codex launch behavior. The helper forks the selected
  thread with `--cd` pointing to the new worktree and switches the tmux client.
  The original conversation remains available in its existing session.
- After the command succeeds, report the worktree path, branch, and tmux session.
  If it fails after creating resources, inspect what exists before retrying and
  report any partial result. Creating the fork does not itself request further
  implementation in the original conversation.
