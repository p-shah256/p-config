#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "./logger.sh"
source "./packages.sh"

log_info "=== Devserver Setup Script ==="

log_info "[1/7] Installing packages via dnf..."
sudo dnf install -y "${DNF_PACKAGES[@]}"

log_info "[2/7] Cloning p-config..."
if [ ! -d ~/p-config ]; then
    git clone --recurse-submodules https://github.com/p-shah256/p-config.git ~/p-config
else
    log_debug "p-config already exists, skipping clone"
fi

log_info "[3/7] Installing Oh My Zsh and plugins..."
if [ ! -d ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ] && \
    git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

log_info "[4/7] Installing Rust/Cargo..."
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

log_info "[5/7] Installing cargo packages..."
source "$HOME/.cargo/env" 2>/dev/null || true
cargo install "${CARGO_PACKAGES[@]}"

log_info "Installing atuin..."
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

log_info "[6/7] Copying dotfiles..."
cp ~/p-config/.zshrc ~/.zshrc
cp ~/p-config/.p10k.zsh ~/.p10k.zsh
mkdir -p ~/.config
cp -r ~/p-config/nvim ~/.config/nvim
cp -r ~/p-config/zellij ~/.config/zellij
cp -r ~/p-config/bash ~/.config/bash

log_info "[7/7] Initializing nvim plugins..."
nvim --headless "+Lazy! sync" +qa

log_info "=== Setup complete! Log out and back in for shell change to take effect ==="
