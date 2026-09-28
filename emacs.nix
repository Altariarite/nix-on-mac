{ pkgs }:

let
  epkgs = pkgs.emacsPackagesFor pkgs.emacs;
  # Native module matching parinfer-rust-mode in our pinned nixpkgs (Apple Silicon).
  parinferLibrary = pkgs.fetchurl {
    url = "https://github.com/justinbarclay/parinfer-rust-emacs/releases/download/v0.4.7/parinfer-rust-darwin.so";
    hash = "sha256-6RyisAv6QoLgREB00qGUNqCcnGhDkOc3UYo+iJn31dU=";
  };
  parinferNative = pkgs.runCommand "emacs-parinfer-native-0.4.7" { } ''
    mkdir -p $out/share/emacs/site-lisp
    ln -s ${parinferLibrary} $out/share/emacs/site-lisp/parinfer-rust-darwin.so
  '';
  hel = epkgs.trivialBuild {
    pname = "hel";
    version = "0-unstable-2026-09-26";
    src = pkgs.fetchFromGitHub {
      owner = "helheim-emacs";
      repo = "hel";
      rev = "7c133defda8c0e3c6c791cde05450c3d43616f06";
      hash = "sha256-Ei2WbCNEl2AzfYj7yGY2rMtJayARkC7nPhVsepDalE0=";
    };
    packageRequires = with epkgs; [
      dash
      avy
      pcre2el
      ultra-scroll
    ];
  };
in
epkgs.emacsWithPackages (epkgs: [
  hel
  epkgs.sly
  epkgs.parinfer-rust-mode
  parinferNative
  epkgs.tuareg
  epkgs.utop
  epkgs.elixir-mode
  epkgs.inf-elixir
  epkgs.nix-mode
])
