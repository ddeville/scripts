#!/bin/sh

ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
timedatectl set-ntp true
hwclock --systohc
sed -i "/#en_US.UTF-8 UTF-8/s/#//" /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "arch" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts

passwd

echo "Server = https://mirrors.sonic.net/archlinux/\$repo/os/\$arch\
Server = https://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch\
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch\
Server = https://mirrors.mit.edu/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

pacman -Syy

pacman -S --needed \
    grub efibootmgr os-prober \
    xf86-video-amdgpu \
    base-devel linux-headers man-db man-pages git pacman-contrib zip unzip lsb-release \
    xdg-user-dirs xdg-utils dialog terminus-font \
    networkmanager network-manager-applet libvncserver \
    openssh rsync openbsd-netcat iptables-nft ipset firewalld gnupg gnome-keyring libsecret \
    avahi bluez bluez-utils cups hplip inetutils dnsutils nss-mdns \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack paxmixer pavucontrol sof-firmware \
    acpi acpi_call acpid \
    mtools dosfstools smbclient gvfs gvfs-smb cifs-utils nfs-utils ntfs-3g btrfs-progs \
    fish vim neovim stow bat exa htop jq ripgrep tmux curl fd \
    cmake ninja python rustup go nodejs npm pyenv tree-sitter perf gdb flamegraph \
    docker qemu qemu-arch-extra libvirt ovmf vde2 bridge-utils dnsmasq dmidecode

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid
systemctl enable libvirtd.service

useradd -m damien
passwd damien
echo "damien ALL=(ALL) ALL" >> /etc/sudoers.d/damien

sudo -u damien -H sh -c "chsh -s /usr/bin/fish"

sudo -u damien -H sh -c "cd \$(mktemp -d -t paru-XXXXXXXXXX); \
    git clone https://aur.archlinux.org/paru.git; \
    makepkg -si;"

sudo -u damien -H sh -c "git clone https://github.com/ddeville/base16-shell.git ~/.local/share/base16-shell"
sudo -u damien -H sh -c "git clone https://github.com/tmux-plugins/tpm ~/scripts/config/common/.config/tmux/plugins/tpm"

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
