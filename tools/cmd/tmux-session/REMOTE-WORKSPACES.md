# Remote workspaces in tm

```sh
tm --host devbox work/api
tm --host devbox work/api --name scratch
```

Relative paths start in the remote home directory. The SSH destination, resolved
directory and workspace name identify a session even after you rename it in tmux.

The picker, copy mode and key bindings stay local. The devbox runs the shell,
`$EDITOR` (default `nvim`) and `codex` under zmx. New windows and splits start in
the project directory. Sessions using the same SSH destination share one OpenSSH
connection. Use the same SSH alias across projects. Each pane uses one of sshd's
`MaxSessions` slots. Leave room for discovery and one channel per open agent
popup. A full connection never falls back to a second login.

- **Reconnect** happens automatically. The first `tm` can prompt for sign-in.
  Each local tmux server runs one supervisor per destination. It retries a lost
  connection with backoff and reattaches surviving terminals in place, including
  moved panes. Input typed into a dead pane is discarded. Programs that ended
  stay closed. If SSH needs attention or recovery stalls, rerun `tm --host …`
  from a local shell. Automatic retries never prompt or accept new host keys.
- **Recover after losing the local tmux server** by reopening each workspace.
  Each surviving terminal gets a window named for its role. Custom titles, order
  and split layouts survive only while the local server does.
- **End a terminal** with prefix `x`, or a whole window with prefix `&`. These
  bindings report unconfirmed closes. Raw tmux kill commands only detach remote
  terminals. Exiting a program on the devbox ends its terminal.
- **Open Codex** with prefix `a`. The popup groups remote conversations by host
  and directory, including Codex started manually in a split. Choose a pane
  when a thread has multiple views. Enter rechecks the thread and pane before
  switching the invoking client. Worktree actions and the CLI status feed stay local.

Use tmux 3.8+ locally. Zmx must be on the devbox's SSH command path. Its sockets live in
`~/.cache/tm-zmx` unless the SSH environment sets `ZMX_DIR`. Forwarded agent
sockets in surviving programs can go stale after reconnecting.

Remote status requires a shared Codex app server, `codex app-server proxy` on
the SSH command path, and `thread-id` last in `tui.terminal_title`. The popup
uses the same title matching locally and remotely. A shortened ID must match
exactly one loaded thread on that host. A stale or forged title can misidentify
a conversation. The popup only queries each app server while open.
