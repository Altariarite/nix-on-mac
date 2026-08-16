{ pkgs, basecampCli }:

with pkgs;
[
  # Dotfile management
  stow

  # Nix command documentation
  nix.man

  # Shells and shell integrations
  fish
  zsh
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
  starship
  fzf
  zoxide

  # Terminal/editor tools
  helix
  zellij
  tealdeer

  # Version control
  jujutsu
  jjui
  jj-starship
  git
  gh
  delta

  # CLI utilities
  fd
  ripgrep
  coreutils
  wget
  tree-sitter
  glow
  uv
  ffmpeg
  zola
  basecampCli

  # macOS applications
  xld

  # Global language support
  nixfmt
  nil
  taplo
  ruby_4_0
  julia
  sbcl
  rlwrap
  babashka
  swi-prolog

  # Fonts
  nerd-fonts.fira-code
  nerd-fonts.iosevka
  nerd-fonts.geist-mono
  nerd-fonts.hack
  nerd-fonts.commit-mono

  # AI
  opencode
  claude-code
]
