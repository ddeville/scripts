#!/bin/bash

set -eu

# Can be overriden from the command line
: "${USERNAME:=damien}"
: "${HOSTNAME:=arch}"

# Setup time and locale
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
# TODO(damien): This needs systemd to be pid1 which isn't the case in an arch-chroot
# timedatectl set-ntp true
hwclock --systohc
sed -i "/#en_US.UTF-8 UTF-8/s/#//" /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "$HOSTNAME" >>/etc/hostname
{
  echo "127.0.0.1 localhost"
  echo "::1       localhost"
  echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME"
} >>/etc/hosts

printf "\e[1;32m==> Setting root password\n\e[0m"
passwd

# Setup pacman mirrors (can be changed to something closer if not in the bay area)
cat <<EOT >/etc/pacman.d/mirrorlist
Server = https://mirrors.sonic.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirrors.mit.edu/archlinux/\$repo/os/\$arch
EOT

# Install grub
pacman -Syy
pacman -S --needed grub efibootmgr os-prober

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install all the base packages
readarray -t base_packages < <(grep -Ev "^\#|^\$" "/scripts/install/arch/base_packages.txt")
pacman -Syy
pacman -S --needed "${base_packages[@]}"

# Setup the systemd services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid
systemctl enable libvirtd
systemctl enable lightdm

# Create user and make sure it can sudo
printf "\e[1;32m==> Creating new user\n\e[0m"
useradd -m "$USERNAME"
passwd "$USERNAME"
mkdir -p /etc/sudoers.d
echo "$USERNAME ALL=(ALL) ALL" >>"/etc/sudoers.d/$USERNAME"

# Make fish the default shell
sudo -u "$USERNAME" -H sh -c chsh -s /usr/bin/fish

# Paru needs `rust` but since we install `rustup` rather than `rust` we need to install a toolchain manually.
sudo -u "$USERNAME" -H sh -c rustup default stable
sudo -u "$USERNAME" -H sh -c rustup component add rust-src rustfmt clippy

# Install Paru
sudo -u "$USERNAME" -H sh -c git clone --depth=1 https://aur.archlinux.org/paru.git "/home/$USERNAME/paru"
sudo -u "$USERNAME" -H sh -c cd "/home/$USERNAME/paru" && makepkg -si
rm -rf "/home/$USERNAME/paru"

# Install the 1Password signing key that we will need to install the package
sudo -u "$USERNAME" -H sh -c curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import

# Install AUR packages with Paru
readarray -t aur_packages < <(grep -Ev "^\#|^\$" "/scripts/install/arch/aur_packages.txt")
sudo -u "$USERNAME" -H sh -c /usr/bin/paru -Syy
sudo -u "$USERNAME" -H sh -c /usr/bin/paru -S --needed "${aur_packages[@]}"

# Move the scripts repo to the home directory
mv /scripts "/home/$USERNAME/scripts"
chown "$USERNAME":"$USERNAME" -R "/home/$USERNAME/scripts"

printf "\e[1;32m==> Done! Type exit, umount -a and reboot.\n\e[0m"
