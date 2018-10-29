-------
Scripts
-------

A bunch of scripts I use on every machine I set up. When setting up a new machine, do the following steps:

* If on MacOS, install `iTerm2 <https://www.iterm2.com/downloads.html>`_
* Clone this repo in the home directory
* Run the install script, this will install various tools and create symbolic links to the config files

::

    > cd ~
    > git clone git@github.com:ddeville/scripts.git
    > ./install

-----
Notes
-----

To make sure that `git` keeps the file executable, run the following::

    git update-index --chmod=+x <file>
