#!/bin/bash
# Package lists for devserver setup

DNF_PACKAGES=(
    bat
    colordiff
    fzf
    gettext
    git
    curl
    lua
    # neovim
    # installed via meta features
    parallel
    ripgrep
    zsh
    util-linux-user
    mtr
    tmux
)

CARGO_PACKAGES=(
    eza
    navi
    zellij
    zoxide
    viddy
)
