# ── general ──────────────────────────────────────────────────────────────────
alias python=python3
alias pip=pip3

# ── fzf ──────────────────────────────────────────────────────────────────────
alias fe='$EDITOR $(fzf)'
alias fkill='kill -9 $(ps aux | fzf --header-lines=1 | awk "{print \$2}")'
alias frecent='open $(ls -t | fzf)'

# git + fzf
alias gs='git status'
alias gst='git status --short'
alias gbr='git checkout $(git branch --all | fzf | tr -d "* ")'
alias glog='git log --oneline --color | fzf --ansi --preview "git show --color=always {1}"'
alias gfa='git add $(git -C . ls-files --modified --others --exclude-standard | fzf -m)'

# ── iTerm2 ───────────────────────────────────────────────────────────────────
_iterm2_profile_path() {
  local machine
  machine=$(scutil --get LocalHostName 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
  echo "$DOTFILES/iterm2/profiles/$machine.json"
}

alias iterm2-log='git -C "$DOTFILES" log --format="%h  %ai  %s" -- "$(_iterm2_profile_path)"'

function iterm2-restore() {
  local hash="$1"
  local profile
  profile="$(_iterm2_profile_path)"

  [[ -n "$hash" ]] || { echo "usage: iterm2-restore <hash>"; return 1; }

  git -C "$DOTFILES" checkout "$hash" -- "$profile" \
    || { echo "✗ checkout failed"; return 1; }

  bash "$DOTFILES/scripts/restore-iterm2.sh" \
    || { echo "✗ restore failed"; return 1; }

  echo "✓ restored — restart iTerm2 to apply"
}

# ── secrets ───────────────────────────────────────────────────────────────────
# Two modes:
#   pass mode  — uncomment the printf lines below and point them at your pass paths.
#   plain mode — skip this function; edit ~/.config/zsh/secrets.zsh directly.
# Run `sync-secrets` after rotating a secret (pass mode only).
function sync-secrets() {
  local secrets_file="$HOME/.config/zsh/secrets.zsh"

  if ! command -v pass &>/dev/null; then
    echo "ℹ  pass is not installed."
    echo "   Edit $secrets_file directly to set your secrets."
    return 0
  fi

  {
    # Uncomment and add your own pass store paths:
    # printf 'export GITHUB_PAT="%s"\n'      "$(pass show tokens/github-pat)"
    # printf 'export OPENAI_API_KEY="%s"\n'  "$(pass show tokens/openai-api-key)"
    :
  } > "$secrets_file"
  echo "✓ secrets synced to $secrets_file"
}
