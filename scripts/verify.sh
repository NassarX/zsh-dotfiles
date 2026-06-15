#!/usr/bin/env bash
# Assert that all expected symlinks exist and point to the right sources.
# Exits non-zero if any symlink is broken or missing.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'
PASS=0; FAIL=0

check() {
  local dest="$1" expected_src="$2"
  local actual_src
  actual_src="$(readlink "$dest" 2>/dev/null || true)"

  if [[ "$actual_src" == "$expected_src" ]]; then
    printf "${GREEN}✓${RESET} %s\n" "$dest"
    PASS=$((PASS + 1))
  else
    printf "${RED}✗${RESET} %s — expected symlink to %s, got: %s\n" \
      "$dest" "$expected_src" "${actual_src:-<not a symlink>}"
    FAIL=$((FAIL + 1))
  fi
}

check "$HOME/.zshrc"              "$DOTFILES/zsh/.zshrc"
check "$HOME/.p10k.zsh"           "$DOTFILES/zsh/.p10k.zsh"
check "$HOME/.config/zsh"         "$DOTFILES/zsh/config"
check "$HOME/.gitconfig"          "$DOTFILES/git/.gitconfig"
check "$HOME/.config/bat/config"  "$DOTFILES/bat/config"

echo ""
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
