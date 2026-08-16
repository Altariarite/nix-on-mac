# macOS Nix Packages and Stow Dotfiles

This repo uses a small Nix flake for pinned inputs and GNU Stow for linking
dotfiles. The files have deliberately separate jobs:

- `package.nix` is the readable package list.
- `flake.nix` is a thin wrapper that supplies pinned packages and builds the list.
- `rebuild.sh` installs the built profile and restows the dotfiles.

The installed profile also exposes the pinned source at
`~/.nix-profile/share/nixpkgs`. Fish and Zsh export this as `NIXPKGS` and set
`NIX_PATH=nixpkgs=$NIXPKGS`, so any `shell.nix` that imports `<nixpkgs>` uses the
same revision as this repository's `flake.lock`:

```nix
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [ ];
}
```

Update the package bundle and all dotfiles together:

```sh
./rebuild.sh
```

The `nix-rebuild` shell alias runs the same script.

Preview a package build without changing the installed profile:

```sh
nix build --no-link path:.#default
```

Update all pinned inputs, including the official Basecamp CLI:

```sh
nix flake update
```

Codex is installed separately with OpenAI's standalone installer so it can
track the fast-moving CLI releases independently of the pinned Nix bundle:

```sh
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Run the same command again to update Codex. The installer puts `codex` in
`~/.local/bin`, which the Fish and Zsh configurations add ahead of the Nix
profile.

After rebuilding, authenticate Basecamp when needed:

```sh
basecamp auth login
```

Fish is the primary interactive shell. It loads Determinate Nix's native Fish
integration, the packaged `jj` and `nix` completions, and the Starship prompt
with `jj-starship` repository status.

Ghostty launches the Nix-installed Fish directly. To also make it the macOS
account login shell, register its stable profile path once and then select it:

```sh
echo /Users/altaria/.nix-profile/bin/fish | sudo tee -a /etc/shells
chsh -s /Users/altaria/.nix-profile/bin/fish
```

Enter a project's Nix development environment with the configured Fish environment:

```sh
nd
```

If the project has a `flake.nix`, `nd` uses `nix develop`; otherwise it falls back
to `nix-shell` and the project's `shell.nix`. Arguments are passed through to the
selected Nix command.
Exit the shell to return to the normal environment.

For OCaml editor support, expose the language server and formatter from the
project's `shell.nix`:

```nix
packages = [
  pkgs.ocamlPackages.ocaml-lsp
  pkgs.ocamlPackages.ocamlformat
];
```

Then launch either editor from the development shell so it inherits those
project-local tools:

```sh
nd
hx .
# or
code .
```

Helix uses `ocamllsp` and formats `.ml`/`.mli` files with `ocamlformat` on
save. VS Code uses the OCaml Platform extension with its global sandbox and
format-on-save enabled. If VS Code was already open outside `nd`, quit it fully
before launching `code .`. OCaml projects should include a root `.ocamlformat`
file; Helix also permits formatting standalone files outside a detected
project.

Add or remove ordinary packages directly in `package.nix`:

```nix
{ pkgs, basecampCli }:

with pkgs; [
  helix
  git
  ripgrep
  basecampCli
]
```

Link dotfiles into `$HOME` without rebuilding the package bundle:

```sh
cd ~/.config/nix
stow -d dotfiles -t ~ zsh starship tealdeer helix zellij fish ghostty
```

Preview Stow changes first:

```sh
stow -n -v -d dotfiles -t ~ zsh starship tealdeer helix zellij fish ghostty
```

Unlink a package:

```sh
stow -D -d dotfiles -t ~ helix
```
