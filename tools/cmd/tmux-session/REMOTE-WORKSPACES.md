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
connection. Each pane uses one of the server's `MaxSessions` slots. Discovery
needs a free slot too.

- **Reconnect** by rerunning `tm` from a local shell. This reconnects failed panes
  across projects on that destination, including moved panes. Input typed into a
  dead pane is discarded. Programs that ended while disconnected stay closed.
- **Recover after losing the local tmux server** by reopening each workspace.
  Each surviving terminal gets a window named for its role. Custom titles, order
  and split layouts survive only while the local server does.
- **End a terminal** with prefix `x`, or a whole window with prefix `&`. These
  bindings report unconfirmed closes. Raw tmux kill commands only detach remote
  terminals. Exiting a program on the devbox ends its terminal.

Zmx must be on the devbox's SSH command path. Its sockets live in
`~/.cache/tm-zmx` unless the SSH environment sets `ZMX_DIR`. Forwarded agent
sockets in surviving programs can go stale after reconnecting. The local agent
dashboard doesn't list remote agents yet.
