#!/usr/bin/env bash
# Restore a pre-install backup created by install.sh.
# Lists available backups and lets you pick one to restore.
set -uo pipefail

BACKUP_ROOT="$HOME/.dotfiles-backup"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'

_ok()   { printf "${GREEN}✓${RESET}  %s\n" "$1"; }
_warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$1"; }
_fail() { printf "${RED}✗${RESET}  %s\n" "$1"; exit 1; }

[[ -d "$BACKUP_ROOT" ]] || _fail "no backups found at $BACKUP_ROOT"

backups=($(ls -1r "$BACKUP_ROOT" 2>/dev/null))
[[ ${#backups[@]} -eq 0 ]] && _fail "no backups found at $BACKUP_ROOT"

echo ""
echo "Available backups:"
for i in "${!backups[@]}"; do
  printf "  [%d] %s\n" "$((i+1))" "${backups[$i]}"
done
echo ""
read -rp "Restore which backup? [1-${#backups[@]}]: " choice

[[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#backups[@]}" ]] \
  || _fail "invalid choice"

selected="$BACKUP_ROOT/${backups[$((choice-1))]}"
echo ""
_warn "this will overwrite your current config files"
read -rp "Continue? [y/N]: " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# Restore each backed-up file/dir to its original location
for item in "$selected"/.*  "$selected"/*; do
  [[ -e "$item" ]] || continue
  name="$(basename "$item")"
  case "$name" in
    .zshrc)           dest="$HOME/.zshrc" ;;
    .gitconfig)       dest="$HOME/.gitconfig" ;;
    .p10k.zsh)        dest="$HOME/.p10k.zsh" ;;
    zsh)              dest="$HOME/.config/zsh" ;;
    config)           dest="$HOME/.config/bat/config" ;;
    *)                continue ;;
  esac
  rm -rf "$dest"
  cp -r "$item" "$dest"
  _ok "restored $dest"
done

echo ""
_ok "restore complete — open a new terminal to apply"
