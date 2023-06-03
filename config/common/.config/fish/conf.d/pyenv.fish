set -gx PYENV_SHELL fish

status --is-interactive; and pyenv virtualenv-init - 2>/dev/null | source
