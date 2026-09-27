#!/bin/sh
set -eu

config_dir="$HOME/.config/nix"
nix profile upgrade --all
stow --restow --dir "$config_dir/dotfiles" --target "$HOME" emacs fish ghostty helix starship tealdeer vifm zellij zsh
