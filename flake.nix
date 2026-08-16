{
  description = "Altaria's macOS packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    basecamp-cli.url = "github:basecamp/basecamp-cli";
    basecamp-cli.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, basecamp-cli, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      nixpkgsSource = pkgs.runCommandLocal "nixpkgs-source" { } ''
        mkdir -p "$out/share"
        ln -s ${nixpkgs} "$out/share/nixpkgs"
      '';
    in
    {
      packages.${system}.default = pkgs.buildEnv {
        name = "altaria-packages";
        paths =
          import ./package.nix {
            inherit pkgs;
            basecampCli = basecamp-cli.packages.${system}.default;
          }
          ++ [ nixpkgsSource ];
      };
    };
}
