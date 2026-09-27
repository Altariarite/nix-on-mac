{ pkgs }:

let
  epkgs = pkgs.emacsPackagesFor pkgs.emacs;
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
  epkgs.tuareg
  epkgs.utop
  epkgs.elixir-mode
  epkgs.inf-elixir
])
