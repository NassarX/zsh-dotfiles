#!/usr/bin/env bash
# Migrate an existing zsh environment into the dotfiles module structure.
# Reads ~/.zshrc, ~/.gitconfig, and ~/.config/zsh/ then distributes content
# into the right module files before symlinking takes over.
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y-%m-%d_%H-%M-%S)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

_ok()   { printf "${GREEN}✓${RESET}  %s\n" "$1"; }
_info() { printf "${CYAN}→${RESET}  %s\n" "$1"; }
_warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$1"; }

_backup() {
  mkdir -p "$BACKUP_DIR"
  cp -r "$1" "$BACKUP_DIR/"
  printf "${YELLOW}⚠${RESET}  backed up %s → %s\n" "$1" "$BACKUP_DIR/"
}

# ── Categorize a single .zshrc line ──────────────────────────────────────────
# Returns: aliases | exports | secrets | tools | keybindings | structural | skip
_categorize() {
  local trimmed="${1#"${1%%[![:space:]]*}"}"

  [[ -z "$trimmed" || "$trimmed" == \#* ]]           && echo "skip"        && return
  [[ "$trimmed" =~ ^alias\ [a-zA-Z] ]]               && echo "aliases"     && return
  [[ "$trimmed" =~ ^function\ [a-zA-Z_] ]]           && echo "aliases"     && return
  [[ "$trimmed" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\(\) ]]   && echo "aliases"     && return
  [[ "$trimmed" =~ ^bindkey[[:space:]] ]]            && echo "keybindings" && return
  [[ "$trimmed" =~ ^eval\ .*init ]]                  && echo "tools"       && return

  if [[ "$trimmed" =~ ^export\ [a-zA-Z0-9_]+= ]]; then
    [[ "$trimmed" =~ ^export\ ZSH= ]]                          && echo "structural" && return
    [[ "$trimmed" =~ ^export\ PATH=.*opt/homebrew ]]           && echo "structural" && return
    local upper; upper=$(echo "$trimmed" | tr '[:lower:]' '[:upper:]')
    [[ "$upper" =~ (KEY|TOKEN|SECRET|PASSWORD|PASS|AUTH) ]]    && echo "secrets"    && return
    echo "exports" && return
  fi

  if [[ "$trimmed" =~ ^(source|\.\ |\[\[.*source|\[.*\].*&&.*source) ]]; then
    [[ "$trimmed" =~ p10k-instant-prompt ]]     && echo "structural" && return
    [[ "$trimmed" =~ oh-my-zsh\.sh ]]           && echo "structural" && return
    [[ "$trimmed" =~ \.config/zsh/\*\.zsh ]]   && echo "structural" && return
    [[ "$trimmed" =~ iterm2_shell_integration ]] && echo "structural" && return
    [[ "$trimmed" =~ powerlevel10k\.zsh-theme ]] && echo "structural" && return
    [[ "$trimmed" =~ \.p10k\.zsh ]]             && echo "structural" && return
    echo "tools" && return
  fi

  [[ "$trimmed" =~ ^(ZSH_THEME|ZSH_DISABLE|ENABLE_CORRECTION|plugins=|zstyle) ]] \
    && echo "structural" && return

  echo "manual"
}

# ── 1. Migrate ~/.zshrc ───────────────────────────────────────────────────────
migrate_zshrc() {
  local src="$HOME/.zshrc"
  [[ -f "$src" && ! -L "$src" ]] || { _info "~/.zshrc not found or already a symlink — skipping"; return 0; }

  echo ""
  echo "── ~/.zshrc ─────────────────────────────────────────────────────────────────"
  _backup "$src"

  local aliases_file="$DOTFILES/zsh/config/aliases.zsh"
  local exports_file="$DOTFILES/zsh/config/exports.zsh"
  local tools_file="$DOTFILES/zsh/config/tools.zsh"
  local keys_file="$DOTFILES/zsh/config/keybindings.zsh"
  local secrets_file="$HOME/.config/zsh/secrets.zsh"
  mkdir -p "$(dirname "$secrets_file")"

  local header="# ── migrated from ~/.zshrc $(date +%Y-%m-%d) ──────────────────────────────────────"
  local added_aliases=0 added_exports=0 added_tools=0 added_keys=0 added_secrets=0
  local manual_items=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    local category
    category=$(_categorize "$line")

    case "$category" in
      skip|structural) continue ;;

      aliases)
        [[ $added_aliases -eq 0 ]] && { printf "\n%s\n" "$header" >> "$aliases_file"; added_aliases=1; }
        echo "$line" >> "$aliases_file"
        _info "aliases.zsh     ← $trimmed"
        ;;

      exports)
        [[ $added_exports -eq 0 ]] && { printf "\n%s\n" "$header" >> "$exports_file"; added_exports=1; }
        echo "$line" >> "$exports_file"
        _info "exports.zsh     ← $trimmed"
        ;;

      tools)
        [[ $added_tools -eq 0 ]] && { printf "\n%s\n" "$header" >> "$tools_file"; added_tools=1; }
        echo "$line" >> "$tools_file"
        _info "tools.zsh       ← $trimmed"
        ;;

      keybindings)
        [[ $added_keys -eq 0 ]] && { printf "\n%s\n" "$header" >> "$keys_file"; added_keys=1; }
        echo "$line" >> "$keys_file"
        _info "keybindings.zsh ← $trimmed"
        ;;

      secrets)
        if [[ $added_secrets -eq 0 ]]; then
          printf "\n# migrated secrets (%s) — move values to pass store or keep here\n" "$(date +%Y-%m-%d)" >> "$secrets_file"
          added_secrets=1
        fi
        echo "$line" >> "$secrets_file"
        _warn "secrets.zsh     ← $trimmed  ⚠ contains secret"
        ;;

      manual)
        manual_items+=("$trimmed")
        ;;
    esac
  done < "$src"

  if [[ ${#manual_items[@]} -gt 0 ]]; then
    echo ""
    _warn "Could not categorize — add these manually to the right module file:"
    for item in "${manual_items[@]}"; do printf "        %s\n" "$item"; done
  fi

  _ok "~/.zshrc migrated"
}

# ── 2. Migrate ~/.gitconfig ───────────────────────────────────────────────────
migrate_gitconfig() {
  local src="$HOME/.gitconfig"
  [[ -f "$src" && ! -L "$src" ]] || { _info "~/.gitconfig not found or already a symlink — skipping"; return 0; }

  echo ""
  echo "── ~/.gitconfig ─────────────────────────────────────────────────────────────"
  _backup "$src"

  local name email
  name=$(git config  --file "$src" user.name  2>/dev/null || true)
  email=$(git config --file "$src" user.email 2>/dev/null || true)

  local dest="$DOTFILES/git/.gitconfig"

  [[ -n "$name"  ]] && git config --file "$dest" user.name  "$name"  && _info "name  → $name"
  [[ -n "$email" ]] && git config --file "$dest" user.email "$email" && _info "email → $email"

  _ok "~/.gitconfig migrated"
}

# ── 3. Migrate ~/.config/zsh/ ─────────────────────────────────────────────────
migrate_config_zsh() {
  local src="$HOME/.config/zsh"
  [[ -d "$src" && ! -L "$src" ]] || { _info "~/.config/zsh not found or already a symlink — skipping"; return 0; }

  echo ""
  echo "── ~/.config/zsh/ ───────────────────────────────────────────────────────────"
  _backup "$src"

  # Files we own — their content was already handled by migrate_zshrc or will be linked
  local owned=("aliases.zsh" "exports.zsh" "fzf.zsh" "keybindings.zsh" "tools.zsh")

  for f in "$src"/*.zsh; do
    [[ -f "$f" ]] || continue
    local fname; fname="$(basename "$f")"

    # Preserve secrets.zsh into the dotfiles dir (gitignored, picked up after symlinking)
    if [[ "$fname" == "secrets.zsh" ]]; then
      cp "$f" "$DOTFILES/zsh/config/secrets.zsh"
      _ok "preserved secrets.zsh → zsh/config/secrets.zsh"
      continue
    fi

    # Skip local.zsh — user will refill it from the example
    if [[ "$fname" == "local.zsh" ]]; then
      cp "$f" "$DOTFILES/zsh/config/local.zsh"
      _ok "preserved local.zsh"
      continue
    fi

    local is_owned=0
    for o in "${owned[@]}"; do [[ "$fname" == "$o" ]] && is_owned=1 && break; done

    if [[ $is_owned -eq 0 ]]; then
      # Unknown file — copy it in; it will be sourced via the *.zsh glob
      cp "$f" "$DOTFILES/zsh/config/$fname"
      _ok "preserved $fname → zsh/config/$fname"
    else
      _warn "$fname: content handled by .zshrc migration above — skipped"
    fi
  done

  _ok "~/.config/zsh/ migrated"
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}Migrating existing config into dotfiles structure...${RESET}\n"
printf "Backup: %s\n" "$BACKUP_DIR"

migrate_zshrc
migrate_gitconfig
migrate_config_zsh

echo ""
printf "${GREEN}${BOLD}Migration complete.${RESET}\n"
echo ""
echo "Review before opening a new terminal:"
echo "  zsh/config/aliases.zsh     — check for duplicates with existing entries"
echo "  zsh/config/exports.zsh     — check for duplicates"
echo "  zsh/config/tools.zsh       — check for duplicates"
echo "  ~/.config/zsh/secrets.zsh  — review any migrated secrets"
echo ""
printf "Originals backed up to: %s\n" "$BACKUP_DIR"
