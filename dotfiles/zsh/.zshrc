export EDITOR=hx
export GEM_HOME="$HOME/.gem"
export PATH="$HOME/.local/bin:$GEM_HOME/bin:$PATH"
export NIXPKGS="$HOME/.nix-profile/share/nixpkgs"
export NIX_PATH="nixpkgs=$NIXPKGS"

alias jj-sync='jj git fetch && jj rebase -d main'
alias nix-rebuild='"$HOME/.config/nix/rebuild.sh"'
alias ze='zellij'

nd() {
  if [[ -f flake.nix ]]; then
    nix develop "$@" --command zsh -i
  else
    nix-shell "$@" --command 'exec zsh -i'
  fi
}

if [ -r "$HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999999'
fi

if [ -r "$HOME/.nix-profile/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]; then
  source "$HOME/.nix-profile/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi

if [ -r "$HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
