#!/bin/bash

set -eu -o pipefail

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
pacman -Syu --needed grub efibootmgr os-prober

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install all the base packages
readarray -t base_packages < <(grep -Ev "^#|^$" "/scripts/config/linux/.config/pkglist/base_packages.txt")
pacman -S --needed "${base_packages[@]}"

cat >/etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "dbus-run-session start-hyprland -- -c /etc/greetd/hyprland.lua"
user = "greeter"
EOF

cat >/etc/greetd/hyprland.lua <<'EOF'
hl.monitor({ output = '', mode = 'preferred', position = 'auto', scale = 1.6 })
hl.config({
  animations = { enabled = false },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_hyprland_guiutils_check = true,
  },
  xwayland = { enabled = false },
})
hl.on('hyprland.start', function()
  hl.exec_cmd("regreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
EOF

if ! grep -q 'pam_gnome_keyring.so' /etc/pam.d/greetd; then
  cat >>/etc/pam.d/greetd <<'EOF'
-auth      optional     pam_gnome_keyring.so
-session   optional     pam_gnome_keyring.so auto_start
EOF
fi

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
systemctl enable greetd

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
