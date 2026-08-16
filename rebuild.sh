#!/bin/sh
set -eu

config_dir="$HOME/.config/nix"
package_path="$(nix build --no-link --print-out-paths "path:$config_dir#default")"

nix-env -ir "$package_path"
stow --restow --dir "$config_dir/dotfiles" --target "$HOME" fish ghostty helix starship tealdeer zellij zsh
