#!/bin/sh

SCRIPT_DIR=$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
  brew_path=/opt/homebrew/bin
else
  brew_path=/usr/local/bin
fi

$brew_path/brew tap homebrew/cask-fonts
$brew_path/brew install \
  bat exa fish htop jq neovim ripgrep stow tmux fd cmake ninja bash zoxide lazygit \
  pyenv pyenv-virtualenv golang node fzf robotsandpencils/made/xcodes \
  stylua shellcheck shfmt checkbashisms buildifier \
  font-anonymous-pro

sudo sh -c "echo $brew_path/fish >> /etc/shells"
chsh -s $brew_path/fish

mkdir -p "$HOME/.local/share"

export CARGO_HOME="$HOME/.local/share/cargo"
export RUSTUP_HOME="$HOME/.local/share/rustup"
curl -fsSL https://sh.rustup.rs | /bin/sh -s -- -y --no-modify-path
"$HOME"/.local/share/cargo/bin/rustup component add rust-src rustfmt clippy
"$HOME"/.local/share/cargo/bin/rustup default stable

git clone https://github.com/ddeville/base16-shell.git "$HOME/.local/share/base16-shell"
git clone https://github.com/tmux-plugins/tpm "$HOME/scripts/config/common/.config/tmux/plugins/tpm"

chflags nohidden "$HOME/Library"
chflags hidden "$HOME/Applications"

mkdir -p "$HOME/.1password"
ln -s "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "$HOME/.1password/agent.sock"
sudo mkdir -p /opt/1Password
sudo ln -s "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" /opt/1Password/op-ssh-sign

"$SCRIPT_DIR"/../../bin/macos/.local/bin/update-terminfo

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

defaults write com.apple.dock wvous-bl-corner -int 4
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 3
defaults write com.apple.dock wvous-br-modifier -int 0
defaults write com.apple.dock wvous-tl-corner -int 11
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 2
defaults write com.apple.dock wvous-tr-modifier -int 0

defaults write com.googlecode.iterm2 PrefsCustomFolder "$HOME/scripts/macos/iterm"

# If you want very thin glyphs in Alacritty, although it might look a bit bad...
# defaults write org.alacritty AppleFontSmoothing -int 0

killall Dock
