#!/bin/sh
set -eu

config_dir="$HOME/.config/nix"
nix profile upgrade --all
stow --restow --dir "$config_dir/dotfiles" --target "$HOME" emacs fish ghostty helix starship tealdeer vifm zellij zsh
# herdr keeps sessions and sockets next to its config, so link only the
# config file into a real ~/.config/herdr instead of linking the directory.
stow --restow --no-folding --dir "$config_dir/dotfiles" --target "$HOME" herdr
