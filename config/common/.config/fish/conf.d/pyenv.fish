set -gx PYENV_SHELL fish

status --is-interactive; and source (pyenv virtualenv-init - 2>/dev/null|psub)
