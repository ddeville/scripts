#!/bin/bash
set -eu

# Can be overriden from the command line
: ${USERNAME:=damien}
: ${HOSTNAME:=arch}

ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
timedatectl set-ntp true
hwclock --systohc
sed -i "/#en_US.UTF-8 UTF-8/s/#//" /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "$HOSTNAME" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

printf "\e[1;32m==> Setting root password\n\e[0m"
passwd

cat <<EOT > /etc/pacman.d/mirrorlist
Server = https://mirrors.sonic.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirrors.mit.edu/archlinux/\$repo/os/\$arch
EOT

pacman -Syy

pacman -S --needed \
    grub efibootmgr os-prober \
    xf86-video-amdgpu \
    base-devel linux-headers pkg-config man-db man-pages git pacman-contrib zip unzip lsb-release \
    xdg-user-dirs xdg-utils dialog terminus-font \
    networkmanager network-manager-applet wireguard-tools libvncserver freerdp \
    openssh rsync openbsd-netcat iptables-nft ipset firewalld gnupg gnome-keyring libsecret polkit \
    avahi bluez bluez-utils cups hplip inetutils dnsutils nss-mdns \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack pamixer pavucontrol sof-firmware \
    acpi acpi_call acpid \
    mtools dosfstools smbclient gvfs gvfs-smb cifs-utils nfs-utils ntfs-3g btrfs-progs \
    fish vim neovim stow bat exa htop jq ripgrep tmux curl fd glances duf dust zoxide \
    cmake ninja python rustup go nodejs npm pyenv tree-sitter perf gdb \
    docker qemu-desktop qemu-emulators-full libvirt ovmf vde2 bridge-utils dnsmasq dmidecode

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
systemctl enable libvirtd

printf "\e[1;32m==> Creating new user\n\e[0m"
useradd -m $USERNAME
passwd $USERNAME
mkdir -p /etc/sudoers.d
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$USERNAME

sudo -u $USERNAME -H sh -c "chsh -s /usr/bin/fish"

# Paru needs `rust` but since we install `rustup` rather than `rust` we need to install a toolchain manually.
sudo -u $USERNAME -H sh -c "rustup default stable"

sudo -u $USERNAME -H sh -c "cd /home/$USERNAME; \
    git clone https://aur.archlinux.org/paru.git; \
    cd paru; \
    makepkg -si;
    rm -rf /home/$USERNAME/paru;"

mv /scripts /home/$USERNAME/scripts
chown $USERNAME:$USERNAME -R /home/$USERNAME/scripts

sudo -u $USERNAME -H sh -c "git clone https://github.com/ddeville/base16-shell.git ~/.local/share/base16-shell"
sudo -u $USERNAME -H sh -c "git clone https://github.com/tmux-plugins/tpm ~/scripts/config/common/.config/tmux/plugins/tpm"

printf "\e[1;32m==> Done! Type exit, umount -a and reboot.\n\e[0m"
