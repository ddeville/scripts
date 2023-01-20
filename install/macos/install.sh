#!/usr/bin/env bash

set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# First install Xcode Command Line Tools if needed
if [ ! -e "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  echo "Installing Xcode Commadn Line Tools"
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$clt_placeholder"
  clt_label_command="/usr/sbin/softwareupdate -l |
		     grep -B 1 -E 'Command Line Tools' |
		     awk -F'*' '/^ *\\*/ {print \$2}' |
		     sed -e 's/^ *Label: //' -e 's/^ *//' |
		     sort -V |
		     tail -n1"
  clt_label="$(chomp "$(/bin/bash -c "$clt_label_command")")"
  if [[ -n $clt_label ]]; then
    echo "Installing $clt_label"
    sudo "/usr/sbin/softwareupdate" "-i" "$clt_label"
    sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
  fi
  sudo rm -f "$clt_placeholder"
fi

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

# We can now install all the packages
"$SCRIPT_DIR"/install_packages

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
  brew_path=/opt/homebrew/bin
else
  brew_path=/usr/local/bin
fi

sudo sh -c "echo $brew_path/fish >> /etc/shells"
chsh -s $brew_path/fish

mkdir -p "$HOME/.local/share"

export CARGO_HOME="$HOME/.local/share/cargo"
export RUSTUP_HOME="$HOME/.local/share/rustup"
/usr/bin/curl -fsSL https://sh.rustup.rs | /bin/sh -s -- -y --no-modify-path
"$HOME"/.local/share/cargo/bin/rustup component add rust-src rustfmt clippy
"$HOME"/.local/share/cargo/bin/rustup default stable

export PATH="$brew_path":$PATH
export XDG_DATA_HOME="$HOME/.local/share"
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$SCRIPT_DIR"/../../bin/common/.local/bin/update-shell-plugins
"$SCRIPT_DIR"/../../bin/macos/.local/bin/update-terminfo

mkdir -p "$HOME/.1password"
ln -s "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "$HOME/.1password/agent.sock"
sudo mkdir -p /opt/1Password
sudo ln -s "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" /opt/1Password/op-ssh-sign

chflags nohidden "$HOME/Library"
chflags hidden "$HOME/Applications"
chflags hidden "$HOME/Public"

defaults write com.apple.loginwindow TALLogoutSavesState -bool true

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
defaults write NSGlobalDomain NSUserKeyEquivalents -dict "Lock Screen" '^$d'

defaults write com.apple.universalaccess closeViewSmoothImages -int 0
defaults write com.apple.universalaccess closeViewScrollWheelToggle -int 1
defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144
defaults write com.apple.universalaccess closeViewHotkeysEnabled -int 0
defaults write com.apple.universalaccess closeViewTrackpadGestureZoomEnabled -bool false

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

defaults write com.googlecode.iterm2 PrefsCustomFolder "$HOME/scripts/macos/iterm"

# If you want very thin glyphs in Alacritty, although it might look a bit bad...
# defaults write org.alacritty AppleFontSmoothing -int 0

killall Dock
