# macOS Nix Packages and Stow Dotfiles

This repo uses a small Nix flake for pinned inputs and GNU Stow for linking
dotfiles. The files have deliberately separate jobs:

- `package.nix` is the readable package list.
- `flake.nix` is a thin wrapper that supplies pinned packages and builds the list.
- `rebuild.sh` upgrades the modern Nix profile and restows the dotfiles.

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

Apply changes to `package.nix` or the local flake from any directory:

```sh
nix profile upgrade --all
```

The profile tracks `path:/Users/altaria/.config/nix#default` as one package
bundle. It re-evaluates the local files and installs the result; it does not
update the pins in `flake.lock`. To update dependencies too, run `nix flake update`
in this repository first, then upgrade the profile.

The active profile is `~/.local/state/nix/profiles/packages`, reached through
`~/.nix-profile`. Manage it with `nix profile`, not `nix-env`.

To also restow all dotfiles, use the optional wrapper:

```sh
./rebuild.sh
```

Any existing `nix-rebuild` alias pointing to this script continues to work.
Stow links reflect edits to existing config files immediately; new Stow packages
still need to be linked.

The previous legacy profile and its generations remain at
`~/.local/state/nix/profiles/profile`. To switch back if needed:

```sh
ln -sfn "$HOME/.local/state/nix/profiles/profile" "$HOME/.nix-profile"
```

After switching back, use the legacy `nix-env` workflow; the updated wrapper
expects the modern profile.

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

Language servers, formatters and REPLs live in `package.nix`, not in project
shells. A project's `shell.nix` carries only what builds and runs that project,
so entering `nd` adds the compiler on top of editor tooling that is already on
`PATH`:

```nix
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [ ocamlPackages.ocaml dune_3 ];
}
```

`dotfiles/helix/.config/helix/languages.toml` names the tools Helix expects,
and each one is in `package.nix`: `ocamllsp` and `ocamlformat`, `rust-analyzer`
with `rustfmt` and `clippy`, `ruby-lsp` and `rubocop`, `expert` and Elixir's
`mix format`, plus `nixfmt`, `nil` and `taplo`.

Launch the editor from the project shell so it also sees the project's compiler:

```sh
nd
hx .
# or
code .
```

Helix formats `.ml`/`.mli` with `ocamlformat` on save. VS Code uses the OCaml
Platform extension with its global sandbox and format-on-save enabled. If VS
Code was already open outside `nd`, quit it fully before launching `code .`.
OCaml projects should include a root `.ocamlformat` file; Helix also permits
formatting standalone files outside a detected project.

One coupling to watch: `ocaml-lsp` is built against a specific compiler, so the
`ocamlPackages.ocaml-lsp` here and the `ocamlPackages.ocaml` in a project shell
must come from the same nixpkgs revision. They do, because this profile exposes
its pinned source and shells import `<nixpkgs>` through `NIX_PATH` as described
above — but a project pinning its own nixpkgs must supply a matching
`ocaml-lsp` itself.

`rust-analyzer` is a language server, not a toolchain: it still needs `cargo`
on `PATH` from the project's own shell or from rustup.

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
stow -d dotfiles -t ~ zsh starship tealdeer helix zellij fish ghostty vifm emacs
stow --no-folding -d dotfiles -t ~ herdr
```

herdr writes its sessions and sockets into `~/.config/herdr`, so only its
`config.toml` is linked (`--no-folding`); the directory itself stays local.

Preview Stow changes first:

```sh
stow -n -v -d dotfiles -t ~ zsh starship tealdeer helix zellij fish ghostty vifm emacs
```

Unlink a package:

```sh
stow -D -d dotfiles -t ~ helix
```

Vifm configuration is managed by `dotfiles/vifm/.config/vifm/vifmrc`.
It starts with two side-by-side file panes and previews disabled; use `w` or
`:view` to toggle previews. Runtime state, colors and scripts stay in
`~/.config/vifm/`.

## Emacs, Hel, and Common Lisp

`emacs.nix` packages vanilla Emacs with pinned Hel, SLY, Tuareg/UTop, and
Elixir/IEx modes, and nix-mode for `.nix` files; SBCL is in
`package.nix`. Stow manages `dotfiles/emacs/.config/emacs/`. The theme is the
built-in light `modus-operandi`. Packages are supplied by Nix, with automatic
activation of old user-installed ELPA packages disabled in `early-init.el`.

Launch `e example.lisp` (short for `emacs -nw`) in the terminal, or
`emacs example.lisp` for the graphical editor. Like `hx .`, `e .` opens the
file picker for that directory over `*scratch*`. The mouse (clicks, selection, wheel) works
in terminal Emacs via `xterm-mouse-mode`. The terminal cursor follows Hel's
state as in the graphical editor: a bar between characters in normal state
(Emacs's cursor always sits between characters, so after selecting a word the
bar sits right after it), a block in insert state, and an underline in Emacs
state. Fish and Zsh alias `emacs` to the Nix executable
to avoid the older `/Applications/Emacs.app`; restart your shell after setup.
Use `M-x sly` (Alt+x, then type `sly`) to start SBCL.
In a Lisp source buffer:

- `g d`: visit a definition through SLY; `[ x`: return.
- `g c`: who calls the function at point; `g C`: what it calls; `g r`: who
  references the global variable at point. Results open in a list: `j`/`k`
  move, `Enter` jumps, `q` closes. In Lisp buffers `g c` replaces Hel's comment
  toggle; `M-;` still comments.
- `Space c` (normal state), or `C-c C-c`: compile/evaluate the current top-level definition.
- `C-c C-k`: compile and load the file.
- `Space r` (normal state), or `C-c C-z`: switch to the REPL.
- `C-x C-s`: save; `C-x C-c`: exit Emacs.
- Saving a Lisp file re-indents it with SLY's Common Lisp rules and removes
  trailing whitespace. With Parinfer on, it asks once before fixing a badly
  indented file.

The REPL starts in insert state; Up/Down recall earlier input (SLY, UTop, IEx). Debugger buffers use standard Emacs commands,
plus `j`/`k` to move down/up the backtrace frames.
Other buffers retain Hel defaults, including xref-based `g d` and `g r` where
a language backend is available. SLY navigation requires a connected Lisp
with the relevant code loaded.

If `~/.emacs.d` exists, Emacs prefers it over the XDG directory. Keep
`~/.emacs.d/init.el` and `~/.emacs.d/early-init.el` linked to their counterparts
in `~/.config/emacs/`. Existing ELPA downloads can remain on disk unused.

In Hel normal state, press `Space` and pause briefly to see the built-in
which-key menu. `Space w` saves the current buffer, `Space q` quits Emacs
(like Vim's `:q`, it refuses while any file has unsaved edits), and `Space f` opens a
Helix-style fuzzy picker over the project's files (Git-aware; the current
directory outside a project). `Space F` opens the plain file prompt in the
current buffer's directory. Minibuffer prompts list matches vertically
(`fido-vertical-mode`): type any part of a name, `C-n`/`C-p` to move, `Enter`.
`Space b` opens Ibuffer: `h/j/k/l` navigate, `Enter` opens the selected buffer,
`d` closes it (prompting for unsaved changes), and `q` returns to the previous view.
Dired (`C-x d`) moves like other read-only buffers and like vifm: `j`/`k` move,
`h` goes to the parent directory, `l` opens, `g g`/`G` jump to the first/last
entry, and `g r` refreshes. Dired's own `j` (go to file) and `k` (hide lines)
move to `J` and `K`. Info manuals use `h/j/k/l` to move, `[ x`/`] x` for
back/forward history (as in Help and EWW), and `[ n`/`] n` for the
previous/next node in reading order.
`Space R` (Shift+r) reloads the saved Emacs config; save edits first with `Space w`.
`Space y` copies the selection to the macOS clipboard, and `Space p`/`Space P`
paste the clipboard after/before the selection, as in Helix. They use
`pbcopy`/`pbpaste`, so they also work in terminal Emacs; plain `y`/`p` keep
using Emacs's own kill ring. `Cmd+C` copies the selection too, and `Cmd+V`
pastes: Emacs turns on the kitty keyboard protocol (`kkp`), and Ghostty passes
`Cmd+C` through to Emacs whenever Ghostty itself has no selection (a
Shift+drag selection is still copied by Ghostty).
`Space t` toggles Parinfer smart mode in the current Lisp source buffer.
It starts disabled, so you can try indentation-driven parenthesis editing per buffer.
The Emacs package and its matching Apple Silicon native module are supplied by Nix.
After installing a new Emacs package, restart Emacs once (config reload alone is insufficient).
`Space c` compiles a Lisp definition. `Space r` starts SLY/SBCL when needed,
then switches to the existing Lisp REPL on subsequent presses in Lisp buffers.
It also opens the Common Lisp REPL from `*scratch*`.
The commands also support OCaml and Elixir as described below. Space still
inserts text in insert state.

After a definition jump, `Space j` displays previous jump locations with
file/buffer names, line numbers, and source text. Select an entry by completing
its label, or press Enter for the most recent location. `C-g` cancels.
`[ x` goes back one step; `] x` goes forward again.

`Space Space` opens the Emacs command palette (`M-x`) from Hel normal state.

Buffers reload on their own when their file changes on disk, for example
when a coding agent edits it; a buffer with unsaved edits is left alone.
`g R` reloads the current buffer by hand.

## herdr

[herdr](https://herdr.dev) is a tmux-like multiplexer that also tracks coding
agents running in its panes (working, blocked, done). Start or reattach with
`herdr`. Its prefix is `Ctrl+Q` (set in `dotfiles/herdr/.config/herdr/config.toml`):
herdr's default `Ctrl+B` is Hel's page-up in Emacs, and macOS uses `Ctrl+Space`
to switch input sources. `Ctrl+Q ?` lists the keybindings and `Ctrl+Q q`
detaches. herdr opens in navigation mode; press `Enter` to type into the pane.

Terminal Emacs works inside herdr unchanged: `Ctrl+B` and other keys reach
Emacs, the cursor changes shape by Hel state (herdr shows it blinking), and
`Cmd+C` still copies the Emacs selection, because herdr passes the kitty
keyboard protocol through from Ghostty.

## OCaml, Elixir, and documentation in Emacs

OCaml (`.ml`, `.mli`) uses Tuareg, UTop, and built-in Eglot with `ocamllsp`.
As in Helix, `g d` goes to a definition, `g y` to the definition of its type,
`g D` to its declaration, and `g r` lists references, which include a
function's callers (`ocamllsp` has no separate "who calls").
Saving formats `.ml`/`.mli` with `ocamlformat`, using the project's
`.ocamlformat` when there is one and the default style for single files; a file
with a syntax error saves unformatted and the error is shown.
Elixir (`.ex`, `.exs`) uses elixir-mode, IEx, and Eglot with `expert --stdio`.
Elixir buffers show `:ok` and `:error` as `✓` and `✗` (so `{:ok, user}` reads
`{✓, user}`) and dim `do`/`end` in code; the original text reappears under the
cursor, and `M-x prettify-symbols-mode` toggles the symbols.
Nix (`.nix`) uses nix-mode and Eglot with `nil`, so `Space k` shows Nix docs.
Eglot starts automatically in source buffers and provides completion,
diagnostics, `g d` definitions, and `g r` references. The existing `Space j`
definition history works for these jumps too.

The Space menu follows the current source language:

| Key | Common Lisp | OCaml | Elixir |
| --- | --- | --- | --- |
| `Space c` | Compile current definition | Evaluate selected region or current phrase | Evaluate selected region or entire buffer |
| `Space r` | SLY/SBCL | UTop | IEx (`iex -S mix` inside a Mix project) |
| `Space k` | Describe symbol | Language-server documentation | Language-server documentation |

Language-server warnings and errors (the underlined text) show their message
when the cursor is on them; `] d` / `[ d` jump to the next/previous one. Emacs 31
hides diagnostics from files outside `trusted-content`; `init.el` exempts
Eglot's checker, which only displays what the language server reports.

Documentation opens in a focused Help buffer to the right of the current
window, in the terminal as in the graphical frame. Repeated lookups reuse
that window and retain page
history. `[ x` or `Alt+Left` goes back; `] x` or `Alt+Right` goes forward.
`Tab` visits links and Enter follows them. Web links open in built-in EWW,
where the same back/forward keys work. `q` closes the documentation window
and returns to the previous view. Help and EWW each keep their own history.
Language-server documentation arrives as Markdown and is rendered with
`markdown-mode`: headings and inline code are styled, the Markdown markup is
hidden, and tagged code blocks (Elixir signatures and specs, OCaml examples)
use the language's own highlighting.

Launch Emacs from the project's `nd` shell so Eglot, UTop, and IEx inherit
the project's compiler, dependencies, and environment. OCaml projects should
use the compiler from this pinned nixpkgs, matching the globally installed
`ocamllsp`. Run `dune build` first for complete project information. Plain
UTop starts without project libraries; for a Dune project, set buffer-local
`utop-command` to `"dune utop . -- -emacs"` (for example with `M-x
set-variable`) before starting UTop. `Space c` is interactive evaluation;
use `M-x compile` for whole-project `dune build` or `mix compile`.

Hel uses its native editing model and cursor shapes: a vertical line in
normal state and a block in insert state. There are no custom delete/append
overrides. With a selection, `d` cuts it and `i`/`a` insert at its beginning/end.
Without a selection, `d` deletes backward, `D` deletes forward, and `i`/`a`
insert at the same position between characters.
