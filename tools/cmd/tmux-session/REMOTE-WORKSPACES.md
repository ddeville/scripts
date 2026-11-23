# Remote workspaces in tm

Use a devbox from the same tmux picker as local projects. The local tmux configuration controls navigation, key bindings, copy mode, and paste. The shell, editor, and Codex run on the devbox.

## Opening and using a workspace

- `tm --host devbox work/api` opens a project using the SSH destination `devbox`. Relative paths start in the remote user's home directory.
- Opening the same remote directory and workspace name reuses the workspace, even after its local session is renamed. A different `--name` opens an independent workspace for the same directory. Projects with the same basename remain distinct.
- A fresh workspace starts with `repo`, `editor`, and `codex` windows. The usual new-window and split bindings open remote shells in the project directory.
- The workspace maintains one authenticated SSH connection to the devbox. Each pane opens its own terminal channel over that connection. After an outage, all panes reattach through the same replacement connection.

## Agent status

The local agent-status popup lists remote Codex agents alongside local agents and shows their current status, even while the user is viewing another workspace. Pressing Enter on a remote agent switches to its workspace and focuses the pane running that agent.

## Disconnecting and reopening

- Detaching, losing connectivity, or losing the local tmux server leaves remote programs running. During an outage, each affected pane shows its connection state and discards typed input. It reconnects automatically when possible and tells the user when sign-in is required.
- Reopening the workspace recreates one local window per surviving remote terminal, including terminals that were split panes. Windows retain their saved names and order. Two windows called `logs` can each reconnect to their own shell. An editor returns with its unsaved buffer intact.
- Closing a pane ends its remote terminal. Closing a window ends the remote terminals it contains. If the host is unreachable, the user sees that the close could not be confirmed. Moving a pane preserves its connection to its original workspace.
- Local projects remain usable while a devbox is unavailable. Removing a local worktree leaves unrelated remote workspaces running.

## Forwarded credentials

When SSH agent forwarding is enabled, Git operations from an already-running remote shell or editor work again after reconnecting.
