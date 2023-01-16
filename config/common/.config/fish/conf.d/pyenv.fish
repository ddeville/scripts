set -gx PYENV_SHELL fish

# NOTE(perf): This seems to take ~220ms to source on an M1 macbook air
status --is-interactive; and pyenv virtualenvs >/dev/null 2>&1; and pyenv virtualenv-init - | source
