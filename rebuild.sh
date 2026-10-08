#!/bin/sh
set -eu

config_dir="$HOME/.config/nix"
nix profile upgrade --all
# macOS only finds fonts under ~/Library/Fonts, and it did not pick up
# symlinks into the profile, so copy the fonts Ghostty may use there.  The
# other Nerd Fonts are copies an earlier Home Manager setup left in
# ~/Library/Fonts/HomeManager.
fonts="$HOME/.nix-profile/share/fonts"
rm -rf "$HOME/Library/Fonts/Nix"
mkdir -p "$HOME/Library/Fonts/Nix"
install -m 644 \
  "$fonts"/truetype/NerdFonts/Lilex/LilexNerdFontMono-*.ttf \
  "$fonts"/opentype/PaperMono-*.otf \
  "$fonts"/opentype/LigaSFMono/*.otf \
  "$fonts"/truetype/psudoFontLigaMono/*.ttf \
  "$fonts"/truetype/LigaHack/*.ttf \
  "$HOME/Library/Fonts/Nix/"
stow --restow --dir "$config_dir/dotfiles" --target "$HOME" emacs fish ghostty helix starship tealdeer vifm zellij zsh
# herdr keeps sessions and sockets next to its config, so link only the
# config file into a real ~/.config/herdr instead of linking the directory.
stow --restow --no-folding --dir "$config_dir/dotfiles" --target "$HOME" herdr
