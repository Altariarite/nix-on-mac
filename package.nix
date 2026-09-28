{
  pkgs,
  basecampCli,
}:

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
  (import ./emacs.nix { inherit pkgs; })
  zellij
  tealdeer
  vifm

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
  tre-command
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
  beamPackages.expert # Elixir language server (used by Helix and VS Code)
  beamPackages.elixir # `mix format`, the Elixir formatter Helix invokes
  ocamlPackages.ocaml-lsp
  ocamlPackages.ocamlformat
  ocamlPackages.utop
  rust-analyzer
  rustfmt
  clippy # rust-analyzer's configured `check` command
  ruby-lsp
  rubocop
  ruby_4_0
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
