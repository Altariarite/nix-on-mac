set -gx EDITOR hx
set -gx GEM_HOME "$HOME/.gem"
set -gx SHELL "$HOME/.nix-profile/bin/fish"
fish_add_path --global "$HOME/.local/bin"
fish_add_path --global "$GEM_HOME/bin"

# A login Fish does not inherit the environment prepared by a POSIX login
# shell, so load Determinate Nix's native Fish integration directly.
if test -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
end

# Make every shell.nix use the nixpkgs revision pinned by this configuration.
set -gx NIXPKGS "$HOME/.nix-profile/share/nixpkgs"
set -gx NIX_PATH "nixpkgs=$NIXPKGS"

function jj-sync --description "Fetch and rebase the current jj repo onto main"
    jj git fetch; and jj rebase -d main
end

function nix-rebuild --description "Rebuild the user Nix packages and dotfiles"
    "$HOME/.config/nix/rebuild.sh" $argv
end

function ze --description "Start Zellij"
    zellij $argv
end

function nd --description "Enter this project's Nix development shell"
    if test -f flake.nix
        nix develop $argv --command fish -i
    else if test -f shell.nix
        nix-shell $argv --run 'exec fish -i'
    else
        echo "nd: no flake.nix or shell.nix found in $PWD" >&2
        return 1
    end
end

if status is-interactive
    set -g fish_greeting

    if command -q fzf
        fzf --fish | source
    end

    if command -q zoxide
        zoxide init fish | source
    end

    if command -q starship
        starship init fish | source
    end
end
