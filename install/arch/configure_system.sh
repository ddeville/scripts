#!/bin/bash

set -eu -o pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "The script needs to be run as root."
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="$script_dir/config"

while IFS= read -r -d '' config_file; do
  target="/etc/${config_file#"$config_dir/"}"
  if ! cmp -s "$config_file" "$target"; then
    install -Dm644 "$config_file" "$target"
  fi
done < <(find "$config_dir" -type f -print0)

install -d -m755 /usr/share/backgrounds

systemctl enable NetworkManager \
  systemd-timedated \
  bluetooth \
  sshd \
  avahi-daemon \
  fstrim.timer \
  firewalld \
  acpid \
  libvirtd

systemctl enable --force greetd

if [ -f /usr/lib/systemd/system/input-remapper.service ]; then
  systemctl enable input-remapper.service
fi
