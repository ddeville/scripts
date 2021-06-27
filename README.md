# Scripts

A bunch of configs and scripts I use on every machine I set up. This repo is named scripts mostly for historical reasons.

A few requirements:

- `python` - at least 2.7.10, ideally 3.6+
- `git` - to clone this repo
- `sudo` - so that the current user can install packages
- if on MacOS, install [iTerm2](https://www.iterm2.com/downloads.html)

```
> cd ~
> git clone git@github.com:ddeville/scripts.git
> ./install run
```

What to do after running the `install` script:

- Add the rust source and linters to the rustup install: `rustup component add rust-src rustfmt clippy`.
- Install the nightly Neovim by running `nvim_nightly_install`.
- Neovim needs some language providers to be installed manually (check with `nvim +checkhealth`):
    - `python2 -m pip install --upgrade pynvim`
    - `python3 -m pip install --upgrade pynvim`
    - `npm install -g neovim`
- Install the various LSP servers by running `lsp_install`.
- Rehash the `pyenv` shims by running `pyenv rehash shell` (and install latest python version).
- If on MacOS, setup the prefs by running `setup_macos_prefs`.
