#!/bin/bash

set -eu

# First install Xcode Command Line Tools if needed
if [ ! -e "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  echo "Installing Xcode Command Line Tools"
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$clt_placeholder"
  clt_label="$(/usr/sbin/softwareupdate -l | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ *\*/ {print $2}' | sed -e 's/^ *Label: //' -e 's/^ *//' | sort -V | tail -n1)"
  if [[ -n $clt_label ]]; then
    echo "Installing $clt_label"
    sudo "/usr/sbin/softwareupdate" "-i" "$clt_label"
    sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
  fi
  sudo rm -f "$clt_placeholder"
fi

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

# We can now install all the packages
"$HOME/scripts/install/macos/install_packages.sh"

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
  brew_path=/opt/homebrew/bin
else
  brew_path=/usr/local/bin
fi

if ! grep -q "$brew_path/fish" /etc/shells; then
  sudo sh -c "echo $brew_path/fish >> /etc/shells"
fi
chsh -s $brew_path/fish

mkdir -p "$HOME/.local/share"

if ! command -v rustup &>/dev/null; then
  export CARGO_HOME="$HOME/.local/share/cargo"
  export RUSTUP_HOME="$HOME/.local/share/rustup"
  curl -fsSL https://sh.rustup.rs | /bin/sh -s -- -y --no-modify-path
fi
"$HOME"/.local/share/cargo/bin/rustup default stable
"$HOME"/.local/share/cargo/bin/rustup component add rust-src rustfmt clippy

export PATH="$brew_path":$PATH

# Run stow to put all the configs and bins in the right place (making sure to first delete a couple of
# configs that might have been created and that would prevent stow from completing successfully)
rm -f "$HOME/.bashrc" "$HOME/.profile"
"$HOME/scripts/bin/common/.local/bin/stow-config"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins"

"$HOME/scripts/bin/macos/.local/bin/update-terminfo"

mkdir -p "$HOME/.1password"
ln -fs "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "$HOME/.1password/agent.sock"
sudo mkdir -p /opt/1Password
sudo ln -fs "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" /opt/1Password/op-ssh-sign

chflags nohidden "$HOME/Library"
if [[ -d "$HOME/Applications" ]]; then
  chflags hidden "$HOME/Applications"
fi
if [[ -d "$HOME/Public" ]]; then
  chflags hidden "$HOME/Public"
fi

spctl developer-mode enable-terminal

# shellcheck disable=SC2016
defaults write NSGlobalDomain NSUserKeyEquivalents -dict "Lock Screen" '^$d'
defaults write NSGlobalDomain NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain AppleAccentColor -int 3
defaults write NSGlobalDomain AppleAquaColorVariant -int 1
defaults write NSGlobalDomain AppleHighlightColor "0.752941 0.964706 0.678431 Green"
defaults write NSGlobalDomain AppleInterfaceStyle "Dark"
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -int 0
defaults write NSGlobalDomain AppleShowAllExtensions -int 1
defaults write NSGlobalDomain ContextMenuGesture -int 0
defaults write NSGlobalDomain com.apple.trackpad.forceClick -int 0

defaults write com.apple.loginwindow TALLogoutSavesState -bool true

defaults write com.apple.dock show-recents -int 0
defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock magnification -int 0
defaults write com.apple.dock mineffect "scale"
defaults write com.apple.dock minimize-to-application -int 1
defaults write com.apple.dock wvous-bl-corner -int 4
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 3
defaults write com.apple.dock wvous-br-modifier -int 0
defaults write com.apple.dock wvous-tl-corner -int 11
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 2
defaults write com.apple.dock wvous-tr-modifier -int 0

defaults write com.apple.activitymonitor ShowCategory -int 100
defaults write com.apple.activitymonitor UpdatePeriod -int 1

# Writing the following will not work unless Terminal/Alacritty is given Full Disk Access...
defaults write com.apple.universalaccess closeViewSmoothImages -int 0
defaults write com.apple.universalaccess closeViewScrollWheelToggle -int 1
defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144
defaults write com.apple.universalaccess closeViewHotkeysEnabled -int 0
defaults write com.apple.universalaccess closeViewTrackpadGestureZoomEnabled -bool false

# Set thin glyphs/strokes in Alacritty
defaults write org.alacritty AppleFontSmoothing -int 0

# If `scripts` was downloaded as an archive, clone the git repo instead
if ! git -C "$HOME/scripts" rev-parse --is-inside-work-tree &>/dev/null; then
  tmp_dir=$(mktemp -d)
  git clone "https://github.com/ddeville/scripts.git" "$tmp_dir/scripts"
  mv "$HOME/scripts" "$tmp_dir/scripts.bak"
  mv "$tmp_dir/scripts" "$HOME/scripts"
  rm -rf "$tmp_dir"
fi

# Make sure that the origin remote is set to use ssh
if [ "$(git -C "$HOME/scripts" remote get-url origin 2>/dev/null)" != "git@github.com:ddeville/scripts.git" ]; then
  git -C "$HOME/scripts" remote set-url origin "git@github.com:ddeville/scripts.git"
fi

killall Finder
killall Dock

printf "\e[1;32m==> Done! You should now reboot.\n\e[0m"
