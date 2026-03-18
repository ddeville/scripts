#!/bin/bash

set -Eeuo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as the user."
  exit 1
fi

trap 'echo "ERROR: install.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

echo "Running macOS install preflight"
sudo -v

arch_name="$(uname -m)"
macos_version="$(sw_vers -productVersion)"
macos_build="$(sw_vers -buildVersion)"
echo "macOS $macos_version ($macos_build) on $arch_name"

if ! pgrep -xu "$USER" Dock >/dev/null; then
  echo "This installer must be run from an interactive Aqua login session." >&2
  exit 1
fi

cd "$HOME"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_TOOLCHAINS_HOME="$HOME/.local/toolchains"

install_command_line_tools() {
  local clt_label clt_placeholder

  clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  trap 'sudo rm -f "$clt_placeholder"' RETURN

  sudo touch "$clt_placeholder"
  clt_label="$(
    /usr/sbin/softwareupdate -l 2>/dev/null |
      sed -n 's/^ *\\* Label: *//p' |
      grep 'Command Line Tools' |
      sort -V |
      tail -n1 || true
  )"

  if [[ -z $clt_label ]]; then
    echo "Unable to find a Command Line Tools update via softwareupdate." >&2
    return 1
  fi

  echo "Installing $clt_label"
  sudo "/usr/sbin/softwareupdate" "-i" "$clt_label"
  sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
}

# First install Xcode Command Line Tools if needed
if [ ! -e "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  echo "Installing Xcode Command Line Tools"
  install_command_line_tools
fi

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

# We can now install all the packages
export SKIP_ALACRITTY_CODESIGN=1
"$HOME/scripts/install/macos/install_packages.sh"

if [ "${arch_name}" = "arm64" ]; then
  brew_path=/opt/homebrew/bin
else
  brew_path=/usr/local/bin
fi

if ! grep -q "$brew_path/fish" /etc/shells; then
  echo "Adding $brew_path/fish to shells"
  sudo sh -c "echo $brew_path/fish >> /etc/shells"
fi
if [ "$SHELL" != "$brew_path/fish" ]; then
  sudo chsh -s "$brew_path/fish" "$USER"
fi

export CARGO_HOME="$XDG_TOOLCHAINS_HOME/rust/cargo"
export RUSTUP_HOME="$XDG_TOOLCHAINS_HOME/rust/rustup"
mkdir -p "$CARGO_HOME"
mkdir -p "$RUSTUP_HOME"
if [ ! -x "$CARGO_HOME"/bin/rustup ]; then
  curl -fsSL https://sh.rustup.rs | /bin/sh -s -- -y --no-modify-path
fi
"$CARGO_HOME"/bin/rustup default stable
"$CARGO_HOME"/bin/rustup component add rust-src rustfmt clippy

export PATH="$brew_path":$PATH

# Run stow to put all the configs and bins in the right place (making sure to first delete a couple of
# configs that might have been created and that would prevent stow from completing successfully)
rm -f "$HOME/.bashrc" "$HOME/.profile"
"$HOME/scripts/bin/common/.local/bin/stow-config"

# Install shell plugins and terminfos
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins"
"$HOME/scripts/bin/macos/.local/bin/update-terminfo"

echo "Setting up 1Password"
mkdir -p "$HOME/.1password"
ln -fs "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "$HOME/.1password/agent.sock"

chflags nohidden "$HOME/Library"
if [[ -d "$HOME/Applications" ]]; then
  chflags hidden "$HOME/Applications"
fi
if [[ -d "$HOME/Public" ]]; then
  chflags hidden "$HOME/Public"
fi

spctl developer-mode enable-terminal

# shellcheck disable=SC2016
defaults write NSGlobalDomain AppleAccentColor -int 3
defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Maximize"
defaults write NSGlobalDomain AppleAquaColorVariant -int 1
defaults write NSGlobalDomain AppleHighlightColor "0.752941 0.964706 0.678431 Green"
defaults write NSGlobalDomain AppleInterfaceStyle "Dark"
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -int 0
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain AppleReduceDesktopTinting -bool true
defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -int 1
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"
defaults write NSGlobalDomain ContextMenuGesture -int 0
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true
defaults write NSGlobalDomain NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false
defaults write NSGlobalDomain SLSMenuBarUseBlurredAppearance -int 1
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain com.apple.swipescrolldirection -int 1
defaults write NSGlobalDomain com.apple.trackpad.forceClick -int 0
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 2
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool false

# shellcheck disable=SC2016
defaults write NSGlobalDomain NSUserKeyEquivalents -dict "Lock Screen" '^$d'

defaults write com.apple.activitymonitor OpenMainWindow -bool true
defaults write com.apple.activitymonitor ShowCategory -int 100
defaults write com.apple.activitymonitor SortColumn -string "CPUUsage"
defaults write com.apple.activitymonitor SortDirection -int 0
defaults write com.apple.activitymonitor UpdatePeriod -int 1

defaults write com.apple.airplay showInMenuBarIfPresent -bool false

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock magnification -int 0
defaults write com.apple.dock mineffect "scale"
defaults write com.apple.dock minimize-to-application -int 1
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock show-recents -int 0
defaults write com.apple.dock wvous-bl-corner -int 4
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 3
defaults write com.apple.dock wvous-br-modifier -int 0
defaults write com.apple.dock wvous-tl-corner -int 11
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 2
defaults write com.apple.dock wvous-tr-modifier -int 0

defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

defaults write com.apple.loginwindow TALLogoutSavesState -bool true

defaults write com.apple.menuextra.battery '{ ShowPercent = NO; }'

defaults write com.apple.siri StatusMenuVisible -bool false
defaults write com.apple.siri VoiceTriggerUserEnabled -bool false

defaults write com.apple.textedit RichText -int 0

# Writing the following will not work unless Terminal/Alacritty is given Full Disk Access...
defaults write com.apple.universalaccess closeViewSmoothImages -int 0
defaults write com.apple.universalaccess closeViewScrollWheelToggle -int 1
defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144
defaults write com.apple.universalaccess closeViewHotkeysEnabled -int 0
defaults write com.apple.universalaccess closeViewTrackpadGestureZoomEnabled -bool false

# Set thin glyphs/strokes in Alacritty
defaults write org.alacritty AppleFontSmoothing -int 0

# Nigthshift
core_brightness_defaults_key="CBUser-$(dscl . -read ~ GeneratedUID | sed 's/GeneratedUID: //')"
core_brightness_defaults_val='{
  CBBlueLightReductionCCTTargetRaw = "3550.0";
  CBBlueReductionStatus =     {
    AutoBlueReductionEnabled = 1;
    BlueLightReductionDisableScheduleAlertCounter = 3;
    BlueLightReductionSchedule =         {
      DayStartHour = 3;
      DayStartMinute = 59;
      NightStartHour = 4;
      NightStartMinute = 0;
    };
    BlueReductionAvailable = 1;
    BlueReductionEnabled = 1;
    BlueReductionMode = 2;
    BlueReductionSunScheduleAllowed = 1;
    Version = 1;
  };
  CBColorAdaptationEnabled = 0;
}'
sudo defaults write /var/root/Library/Preferences/com.apple.CoreBrightness.plist "$core_brightness_defaults_key" "$core_brightness_defaults_val"

# Remap Caps Lock as Control (see https://developer.apple.com/library/archive/technotes/tn2450/_index.html)
modifiermapping="$(
  hidutil list --ndjson | jq -r '
    select(
      ."Built-In" == true and
      .PrimaryUsagePage == 1 and
      .PrimaryUsage == 6
    )
    | "com.apple.keyboard.modifiermapping.\(.VendorID)-\(.ProductID)-0"
  ' | head -n1
)"
if [[ -n $modifiermapping ]]; then
  hidutil property --set '{
    "UserKeyMapping": [{
      "HIDKeyboardModifierMappingSrc": 0x700000039,
      "HIDKeyboardModifierMappingDst": 0x7000000E0,
    }]
  }'
  defaults -currentHost write NSGlobalDomain "$modifiermapping" -array '{
    HIDKeyboardModifierMappingSrc = 30064771129;
    HIDKeyboardModifierMappingDst = 30064771296;
  }'
else
  echo "Unable to find a built-in keyboard for persistent modifier mapping." >&2
fi

# Set some file associations
duti -s com.apple.TextEdit public.yaml all
duti -s com.apple.TextEdit public.json all
duti -s com.apple.TextEdit .toml all
duti -s com.apple.TextEdit .srt all
duti -s org.alacritty public.unix-executable all

defaultbrowser chrome

# Make sure that Spotify doesn't start on login...
spotify_prefs_dir="$HOME/Library/Application Support/Spotify"
spotify_prefs_file="$spotify_prefs_dir/prefs"
mkdir -p "$spotify_prefs_dir"
touch "$spotify_prefs_file"
if ! grep -q "app.autostart-mode" "$spotify_prefs_file"; then
  {
    echo 'app.autostart-mode="off"'
    echo 'app.autostart-banner-seen=true'
    echo 'app.autostart-configured=true'
  } >>"$spotify_prefs_file"
fi

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
