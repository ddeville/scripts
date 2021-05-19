# Scripts

A bunch of scripts/configs I use on every machine I set up.

A few requirements:

- `python` - preferably 2.7.10 or later, 3 even better
- `git` - to clone this repo
- `sudo` - so that the current user can install packages
- if on MacOS, install [iTerm2](https://www.iterm2.com/downloads.html)

```
> cd ~
> git clone git@github.com:ddeville/scripts.git
> ./install run
```

Things to do:

- Add the rust source and linters to the rustup install (for YCM to offer auto completion): `rustup component add rust-src rustfmt clippy`.
- Install Jedi for Python auto completion: `pip install jedi`
- Neovim needs some language providers to be installed manually (check with `nvim +checkhealth`):
    - `python2 -m pip install --upgrade pynvim`
    - `python3 -m pip install --upgrade pynvim`
    - `npm install -g neovim`
