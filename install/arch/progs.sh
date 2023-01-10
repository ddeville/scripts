#!/bin/bash
set -eu

paru -S --needed \
    dropbox nautilus-dropbox dropbox-cli \
    google-chrome 1password 1password-cli spotify slack discord zoom \
    duplicity sysz flamegraph pyenv-virtualenv \
    stylua shellcheck buildifier-bin
