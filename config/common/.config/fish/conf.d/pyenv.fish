set -gx PYENV_SHELL fish

status --is-interactive; and pyenv virtualenvs >/dev/null 2>&1; and pyenv virtualenv-init - | source
