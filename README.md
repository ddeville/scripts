## Scripts

A bunch of scripts I use on every machine I set up. A lot of inspiration was taken from a [post](http://furbo.org/2014/09/03/the-terminal/) by Craig Hockenberry.

When setting up a new machine, do the following steps:

* Clone this repo in the Home directory:
```
> cd ~
> git clone git@github.com:ddeville/scripts.git
```

* Install the following Sublime Text packages:

- [Package Control](https://packagecontrol.io/installation)
- [Theme - Aristocat](https://packagecontrol.io/packages/Theme%20-%20Aristocat)
- [SideBarEnhancements](https://packagecontrol.io/packages/SideBarEnhancements)
- [BracketHighlighter](https://packagecontrol.io/packages/BracketHighlighter)
- [SublimeLinter](https://packagecontrol.io/packages/SublimeLinter)

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

#### Notes

For additional `vim` color schemes, see this [page](http://vimcolorschemetest.googlecode.com/svn/html/index-c.html).

To show the AppleScript scripts in FastScripts, run `defaults write com.red-sweater.FastScripts ScriptTreePathsKey '("FSSP%%%$HOME$/Scripts/applescript")'`.

To make sure that `git` keeps the file executable, run the following `git update-index --chmod=+x <file>`.
