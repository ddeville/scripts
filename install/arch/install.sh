#!/bin/bash

set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "The script needs to be run as root."
  exit 1
fi

# Can be overriden from the command line
: "${USERNAME:=damien}"
: "${HOSTNAME:=arch}"

# Setup time and locale
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc
sed -i "/#en_US.UTF-8 UTF-8/s/#//" /etc/locale.gen
locale-gen

printf "LANG=en_US.UTF-8\n" >/etc/locale.conf
printf "%s\n" "$HOSTNAME" >/etc/hostname
cat >/etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

printf "\e[1;32m==> Setting root password\n\e[0m"
passwd

# Setup pacman mirrors (can be changed to something closer if not in the bay area)
cat <<EOT >/etc/pacman.d/mirrorlist
Server = https://mirrors.sonic.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch
Server = https://arch.hu.fo/archlinux/\$repo/os/\$arch
Server = https://mirror.hackingand.coffee/arch/\$repo/os/\$arch
Server = https://mirrors.mit.edu/archlinux/\$repo/os/\$arch
EOT

# Install grub
pacman -Syy
pacman -S --needed grub efibootmgr os-prober

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install all the base packages
readarray -t base_packages < <(grep -Ev "^#|^$" "config/linux/.config/pkglist/base_packages.txt")
pacman -Syy
pacman -S --needed "${base_packages[@]}"

# Setup the systemd services
systemctl enable NetworkManager
systemctl enable systemd-timedated
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

# Move the scripts repo to the home directory and owned by the new user
mv /scripts "/home/$USERNAME/scripts"
chown "$USERNAME":"$USERNAME" -R "/home/$USERNAME/scripts"

# Continue installation as the user
sudo -u "$USERNAME" -H "/home/$USERNAME/scripts/install/arch/install_as_user.sh"

printf "\e[1;32m==> Once done, type exit, umount -a and reboot.\n\e[0m"
