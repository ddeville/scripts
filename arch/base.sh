#!/bin/sh

ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
timedatectl set-ntp true
hwclock --systohc
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
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
    base-devel linux-headers man-db man-pages git vim python pacman-contrib \
    xdg-user-dirs xdg-utils dialog \
    networkmanager network-manager-applet \
    openssh rsync openbsd-netcat iptables ipset firewalld gnupg \
    avahi bluez bluez-utils cups hplip inetutils dnsutils nss-mdns \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack pavucontrol sof-firmware \
    acpi acpi_call acpid \
    mtools dosfstools gvfs gvfs-smb nfs-utils ntfs-3g

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

useradd -m damien
passwd damien
echo "damien ALL=(ALL) ALL" >> /etc/sudoers.d/damien

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
