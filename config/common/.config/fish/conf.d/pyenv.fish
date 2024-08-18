set -gx PYENV_SHELL fish

status --is-interactive; and type -fq pyenv; and source (pyenv virtualenv-init - 2>/dev/null|psub)
