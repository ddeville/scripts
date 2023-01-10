#!/bin/bash

# We use the ssh-agent that comes with 1password and only store the private keys in its vault.
#
# That means that the only two ssh-agents we should ever use are:
#   1. the one from 1password itself, and thus the socket it listens on at `~/.1password/agent.sock`
#      assuming we are using the machine locally and can interact with its GUI.
#   2. an ssh-agent that was forwarded by openssh.
#
# Given this, here are a few rules that we follow:
#   - If we are in an SSH session, we should never use 1password but only use the forwarded agent, if any, as
#     will be specified by the `SSH_AUTH_SOCK` environment variable.
#   - If we are running inside tmux, we need to figure out whether we are over an active SSH session. The best
#     way to achieve this is to check whether the `SSH_CONNECTION` environment variable is available from tmux.
#     Note that it is still possible for a tmux session to be attached locally while an SSH session is also
#     attached, in which case the SSH agent will take priority, which is unfortunate but more intuitive...
#   - Otherwise, we should use the 1password ssh-agent if the socket it listens on exists on disk.
#   - Otherwise, we can default to whatever was specified in `SSH_AUTH_SOCK`, which will likely be the agent
#     managed by `launchd` on macos and whatever is used on random linux servers.
#     Note that if we ever reach this point it is unlikely that SSH will work at all since we use `IdentityFile`
#     all over the place in the config and agents that are not 1password (or forwarded) won't have those keys.
#

# First get the OpenSSH version since `IdentityAgent` was first introduced in 7.3
ssh_ver=$(ssh -V 2>&1 | sed 's/,.*//; s/^OpenSSH_//; s/[^0123456789.].*//')
ssh_major=$(echo $ssh_ver | awk -F'.' '{printf $1}')
ssh_minor=$(echo $ssh_ver | awk -F'.' '{printf $2}')
if [ "$ssh_major" -lt "7" ]; then
  exit 1
elif [ "$ssh_major" -eq "7" ] && [ "$ssh_minor" -lt "3" ]; then
  exit 1
fi

# If we're over an active SSH connection we shouldn't use the local 1p agent.
if [ -n "$SSH_CONNECTION" ]; then
  exit 1
fi

# If we're in tmux and attached from a shell that has an active SSH connection we shouldn't use the local 1p agent.
if [ -n "$TMUX" ]; then
  # `tmux show-environment SSH_CONNECTION` outputs the following:
  #   - `-SSH_CONNECTION` when the variable is not set
  #   - `SSH_CONNECTION=192.168.101.24 49370 192.168.101.26 22` when it is set
  if [[ $(tmux show-environment SSH_CONNECTION) == *=* ]]; then
    exit 1
  fi
fi

# Only use 1p if the socket exists (either as a socket or a symlink to one).
[ -e ~/.1password/agent.sock ] && exit 0 || exit 1
