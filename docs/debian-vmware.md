### Download and install
First, download [Debian](https://www.debian.org) and start the installation in VMWare.

### Install vmware tools
```
sudo apt-get install open-vm-tools open-vm-tools-desktop
```

### Update screen resolution
Open Displays in settings and select 2560 x 1600

### Set HiDPI mode
```
gsettings set org.gnome.desktop.interface scaling-factor 2
```

### Disable Gnome 3 animations
```
gsettings set org.gnome.desktop.interface enable-animations false
```

### Set dark mode
Open Tweak Tool and toggle Global Dark Theme

### Keyboard
If running on a MacBook with a British keyboard layout, open Region & Languages in Settings and change the input source to "English (UK, Macintosh)"
