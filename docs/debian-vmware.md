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

### SSH
When connecting to the VM via SSH, it will repeatedly ask for the public key passphrase when performing SSH operations but will complain that is cannot open a connection to the authentication agent when running `ssh-add`. To fix this, do:
```
eval (ssh-agent -c)
ssh-add ~/.ssh/id_rsa
```

### Headless VM
It's possible to run the VM headless with VMWare Fusion. The app exposes a `vmrum` utility that can be used to manage virtual machines.
```
# display the list of running VMs
vmrun list
# start the Debian vm
vmrun start ~/vms/debian.vmwarevm nogui
# pause and unpause the vm
vmrun pause ~/vms/debian.vmwarevm nogui
vmrun unpause ~/vms/debian.vmwarevm nogui
# stop the vm
vmrun stop ~/vms/debian.vmwarevm nogui
```
