# Scripts

A bunch of scripts/configs I use on every machine I set up.

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

Things to do:

- Add the rust source and linters to the rustup install: `rustup component add rust-src rustfmt clippy`.
- Install the nightly Neovim by running `nvim_nightly_install`.
- Neovim needs some language providers to be installed manually (check with `nvim +checkhealth`):
    - `python2 -m pip install --upgrade pynvim`
    - `python3 -m pip install --upgrade pynvim`
    - `npm install -g neovim`
- Install the various LSP servers by running `lsp_install`.
