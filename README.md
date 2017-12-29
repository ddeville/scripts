## Scripts

A bunch of scripts I use on every machine I set up.

When setting up a new machine, do the following steps:

* Install [iTerm2](https://www.iterm2.com/downloads.html)

* Clone this repo in the Home directory:
```
> cd ~
> git clone git@github.com:ddeville/scripts.git
```

* Run the setup, this will install various tools and create symbolic links to the dotfiles:
```
> python setup.py
```

#### Notes

For additional `vim` color schemes, see this [page](http://vimcolorschemetest.googlecode.com/svn/html/index-c.html).

To make sure that `git` keeps the file executable, run the following `git update-index --chmod=+x <file>`.
