---
name: worktree
description: Manage personal Git worktrees and tmux/Codex sessions with wt (worktree). Use when the user asks to create, list, reopen, or remove a worktree with this tooling, or fork the current conversation into a named worktree.
---

# Worktrees

Use the installed `wt` command, an alias for `worktree`. For this personal tmux
workflow, let it own checkout paths, branches, and sessions rather than creating
them with raw Git or Codex-managed worktree tools. Use `wt <command> --help` for
current options.

## Create

**Fork the current thread by default** when creating a named worktree/session.
For `$worktree my-feature`, run from the source checkout:

```sh
wt create --fork-current --base HEAD -- my-feature
```

Use `-C /path/to/repo` when the source checkout differs from the command's working
directory. Use the supplied name (a single directory name); ask only if the name
is unclear. Quote names and paths in commands.

- `--fork-current` reads `CODEX_THREAD_ID` from the command environment. If it is
  missing, report that instead of guessing a thread or opening a picker. For an
  explicitly supplied thread ID, replace it with `--fork "$thread_id"`. Omit both
  flags only when the user requests the thread picker.
- Default to explicit `--base HEAD`; use the requested ref instead, such as
  `--base master`. Without `--base`, the CLI rejects dirty source checkouts.
  Explicit `--base` deliberately leaves staged, unstaged, and untracked changes
  in the source. No extra confirmation is needed; briefly note their exclusion
  when the source is dirty. Do not copy, commit, stash, or discard them.
- Creation opens repo, editor, and Codex windows and switches/attaches to tmux.
  Use `--no-switch` for background creation or a caller that cannot attach.
  For a Git-only request, use `--no-tmux` and omit the fork flags.
- The CLI owns naming and honors `GIT_SRC_WORKTREE_DIR` or `--root`. Reuse any
  custom root for later commands; report actual paths and session names.

## Inspect and reopen

Use `wt list --json` for paths, branches, Git status, and matching tmux sessions.
Use `wt open -- repo/name` to reuse an existing session or recreate missing
windows. It also accepts a worktree name or path; `repo/name` avoids ambiguity.
Add `--no-switch` to prepare the session without switching/attaching.

A recreated session launches `codex resume`, not the original fork. If creation
fails after adding the checkout, inspect the existing resources before retrying;
`wt create` refuses an existing path or branch. Reopening the session does not
prove that the requested conversation was forked.

For an explicitly requested interactive browser, use `agents tui --area worktrees`.

## Remove

For a requested removal, inspect `wt remove --dry-run -- repo/name`, then use
`wt remove --yes -- repo/name` for the authorized cleanup. It removes the clean
checkout, its merged branch, and matching tmux sessions. Add `--keep-branch` to
both commands when retaining the branch, including unmerged work. If the checkout
is dirty, report the blocker without discarding changes. Use an explicit target
so omission cannot select the caller's checkout accidentally.

Report the resulting checkout, branch, and session state, including any partial
failure. Distinguish session creation from a verified Codex fork. Creating a fork
does not itself request further implementation in the original conversation.
