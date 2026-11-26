# Remote workspaces in tm

```sh
tm --host devbox work/api
tm --host devbox work/api --name scratch
```

Relative paths start in the remote home directory. The SSH destination, resolved
directory and workspace name identify a session even after you rename it in tmux.

The picker, copy mode and key bindings stay local. The devbox runs the shell,
`$EDITOR` (default `nvim`) and `codex` under zmx. New windows and splits start in
the project directory.

Each remote workspace in local tmux gets its own OpenSSH connection. The two sessions
above have independent connections and pane limits. Renaming a session or
moving a pane keeps its original connection. To resolve an unfamiliar path
that might point to an open workspace, `tm` can use a live connection to the
same SSH destination for discovery.

Each pane uses one of sshd's `MaxSessions` slots. `tm` reserves one slot per
connection for workspace discovery and closing terminals. With a limit of 10,
each session can have nine remote panes.
Discovery keeps its SSH session open while the windows start. Splits and
reconnects briefly occupy the same slot. sshd enforces the limit.
A fresh workspace tries `repo`, `editor`, then `codex`. On refusal,
it keeps the windows that opened and names the ones it skipped. If none fit,
the open fails. Start skipped programs manually in a new window or split when
there's room. A refused split closes with a tmux message. A refusal never
triggers a second login.

- **Connect** with a trusted SSH host key and a working agent. `tm` opens the
  master before creating panes. OpenSSH manages the connection and closes it
  after 60 seconds without a client. Logins use batch mode and strict host-key
  checking. For a new host, verify its key with ordinary `ssh` first. OpenSSH
  honors `IdentityAgent`. Each successful open saves the current `SSH_AUTH_SOCK`
  path in the private connection lock file. Login does not require forwarding.
- **Reconnect** happens automatically. When a pane loses SSH, a tmux
  `pane-died` hook starts recovery for its connection. One job retries with
  backoff and reattaches surviving terminals in place, including moved panes.
  It exits when recovery is done. If fewer slots are available,
  remaining panes wait for room. Input typed into a dead pane is discarded.
  Programs that ended stay closed. If SSH needs attention, fix the agent or
  host key and rerun `tm --host …` from a local shell.
- **Recover after losing the local tmux server** by reopening each workspace.
  Each surviving terminal gets a window named for its role. Custom titles, order
  and split layouts survive only while the local server does.
- **End a terminal** with prefix `x`, or a whole window with prefix `&`. These
  bindings report unconfirmed closes. Raw tmux kill commands only detach remote
  terminals. Exiting a program on the devbox ends its terminal.

Use tmux 3.8+ locally. Zmx must be on the devbox's SSH command path. Its sockets live in
`~/.cache/tm-zmx` unless the SSH environment sets `ZMX_DIR`. Forwarded agent
sockets in surviving programs can go stale after reconnecting.

The agent popup and status feed show local conversations only.
