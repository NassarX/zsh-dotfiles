#!/usr/bin/env bash
# Symlink all dotfiles into their expected system locations.
# Backs up existing real files before replacing. Safe to re-run.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y-%m-%d_%H-%M-%S)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'

_ok()   { printf "${GREEN}✓${RESET} %s → %s\n" "$1" "$2"; }
_skip() { printf "${YELLOW}⚠${RESET} %s already symlinked — skipping\n" "$1"; }
_back() { printf "${YELLOW}⚠${RESET} backed up %s → %s\n" "$1" "$2"; }

link_file() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || { printf "${YELLOW}⚠${RESET} source missing, skipping: %s\n" "$src"; return 0; }
  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local current_target
    current_target="$(readlink "$dest" 2>/dev/null || true)"
    if [[ "$current_target" == "$src" ]]; then
      _skip "$dest"
      return
    else
      rm "$dest"
    fi
  fi

  if [[ -e "$dest" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest")"
    _back "$dest" "$BACKUP_DIR/"
  fi

  ln -s "$src" "$dest"
  _ok "$src" "$dest"
}

link_dir() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || { printf "${YELLOW}⚠${RESET} source missing, skipping: %s\n" "$src"; return 0; }
  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local current_target
    current_target="$(readlink "$dest" 2>/dev/null || true)"
    if [[ "$current_target" == "$src" ]]; then
      _skip "$dest"
      return
    else
      rm "$dest"
    fi
  fi

  if [[ -d "$dest" && ! -L "$dest" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest")-dir"
    _back "$dest" "$BACKUP_DIR/"
  fi

  ln -s "$src" "$dest"
  _ok "$src" "$dest"
}

# ── symlink map ───────────────────────────────────────────────────────────────
link_file "$DOTFILES/zsh/.zshrc"         "$HOME/.zshrc"
link_file "$DOTFILES/zsh/.p10k.zsh"      "$HOME/.p10k.zsh"
link_dir  "$DOTFILES/zsh/config"         "$HOME/.config/zsh"
link_file "$DOTFILES/git/.gitconfig"     "$HOME/.gitconfig"
link_file "$DOTFILES/bat/config"         "$HOME/.config/bat/config"
