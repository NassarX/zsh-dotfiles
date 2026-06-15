# ── pyenv ────────────────────────────────────────────────────────────────────
command -v pyenv &>/dev/null && eval "$(pyenv init --path)"

# ── nvm ──────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]          && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── bun completions ───────────────────────────────────────────────────────────
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ── machine-specific (gitignored, not in repo) ────────────────────────────────
[ -f ~/.config/zsh/local.zsh ] && source ~/.config/zsh/local.zsh
