## Scripts

A bunch of scripts I use on every machine I set up. A lot of inspiration was taken from a [post](http://furbo.org/2014/09/03/the-terminal/) by Craig Hockenberry.

When setting up a new machine, do the following steps:

* Clone this repo in the Home directory:
```
> cd ~
> git clone git@github.com:ddeville/scripts.git
```

* Run the setup, this will create symbolic links for the dotfiles:
```
> ./setup.sh
```

* Manually install the Terminal theme by double-clicking it and making it default in Terminal.
The Xcode and BBEdit themes will be automatically installed but they will have to be selected in their respective apps.

#### Notes

For additional `vim` color schemes, see this [page](http://vimcolorschemetest.googlecode.com/svn/html/index-c.html).

To show the AppleScript scripts in FastScripts, run `defaults write com.red-sweater.FastScripts ScriptTreePathsKey '("FSSP%%%$HOME$/Scripts/applescript")'`.

To make sure that `git` keeps the file executable, run the following `git update-index --chmod=+x <file>`.
