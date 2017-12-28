## Scripts

A bunch of scripts I use on every machine I set up.

When setting up a new machine, do the following steps:

* Clone this repo in the Home directory:
```
> cd ~
> git clone git@github.com:ddeville/scripts.git
```

* Install the [Fish](http://fishshell.com/) shell.
Make the Fish shell the default shell by running the following command:

```
chsh -s /usr/local/bin/fish
```

* Run the setup, this will create symbolic links for the dotfiles:
```
> ./setup.sh
```

* Manually install the Terminal theme by double-clicking it and making it default in Terminal.
The Xcode will be automatically installed but it will have to be selected in the Preferences.

* Install [iTerm2](https://www.iterm2.com/downloads.html) and set its prefs to sync to `~/scripts/iterm`.

#### Notes

For additional `vim` color schemes, see this [page](http://vimcolorschemetest.googlecode.com/svn/html/index-c.html).

To make sure that `git` keeps the file executable, run the following `git update-index --chmod=+x <file>`.
