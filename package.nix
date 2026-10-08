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
  herdr
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
  beamPackages.elixir_1_20 # `mix format` for Helix; Expert type-checks with this Elixir
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
  nerd-fonts.lilex
  paper-mono # ligatures (-> |> => ...) with font-feature ss01
  # Menlo/Meslo with Lilex's ligatures (-> |> => ...); OFL-licensed.
  (stdenvNoCC.mkDerivation rec {
    pname = "psudofont-liga-mono";
    version = "2.2.0";
    src = fetchzip {
      url = "https://github.com/psudo-dev/psudofont-liga-mono/releases/download/v.${version}/psudoFont_Liga_Mono_V.${version}.zip";
      stripRoot = false; # the zip also holds macOS __MACOSX metadata
      hash = "sha256-t9OQpK2ycft4aKZcyCW63YBhLvLNuM6stkHWXQBhRiU=";
    };
    installPhase = "install -Dm644 -t $out/share/fonts/truetype/psudoFontLigaMono psudoFont_Liga_Mono_V.${version}/*.ttf";
  })
  # Hack with Fira Code's ligatures (|> as a triangle), from Ligaturizer's
  # prebuilt release (2021).  Hack's MIT/Bitstream Vera licence allows it.
  (stdenvNoCC.mkDerivation {
    pname = "liga-hack";
    version = "5";
    src = fetchzip {
      url = "https://github.com/ToxicFrog/Ligaturizer/releases/download/v5/LigaturizedFonts.zip";
      stripRoot = false;
      hash = "sha256-2ywFe7khH4WRmQoKwkDHacqKOPGve5fYFaNYGoPJsQ4=";
    };
    installPhase = "install -Dm644 -t $out/share/fonts/truetype/LigaHack LigaHack-*.ttf";
  })
  # Apple's SF Mono patched with Nerd Font icons and Fira Code ligatures.
  # Unmaintained since 2023, and Apple's licence does not permit modified copies.
  (stdenvNoCC.mkDerivation {
    pname = "liga-sf-mono-nerd-font";
    version = "0-unstable-2023-07-02";
    src = fetchFromGitHub {
      owner = "shaunsingh";
      repo = "SFMono-Nerd-Font-Ligaturized";
      rev = "dc5a3e6fcc2e16ad476b7be3c3c17c2273b260ea";
      hash = "sha256-AYjKrVLISsJWXN6Cj74wXmbJtREkFDYOCRw1t2nVH2w=";
    };
    installPhase = "install -Dm644 -t $out/share/fonts/opentype/LigaSFMono *.otf";
  })

  # AI
  opencode
  claude-code
]
