#!/usr/bin/env bash
# Lint .zshrc for content that belongs in a module file instead.
# Exit code: 0 = clean, 1 = violations found.
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSHRC="${1:-$DOTFILES/zsh/.zshrc}"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

violations=0
current_line=0

_violation() {
  local line="$1" content="$2" suggestion="$3"
  printf "${RED}✗${RESET} line %-4s %s\n" "$line" "$content"
  printf "       ${YELLOW}→ move to:${RESET} %s\n" "$suggestion"
  violations=$((violations + 1))
}

# Lines allowed to contain exports in .zshrc (structural, must come early)
_allowed_export() {
  local line="$1"
  [[ "$line" =~ ^export\ ZSH= ]]         && return 0
  [[ "$line" =~ ^export\ PATH=.*homebrew ]] && return 0
  [[ "$line" =~ ^export\ PATH=.*opt/homebrew ]] && return 0
  return 1
}

# Lines allowed to contain source in .zshrc
_allowed_source() {
  local line="$1"
  [[ "$line" =~ p10k-instant-prompt ]]    && return 0
  [[ "$line" =~ oh-my-zsh\.sh ]]          && return 0
  [[ "$line" =~ \.config/zsh/\*\.zsh ]]  && return 0
  [[ "$line" =~ iterm2_shell_integration ]] && return 0
  [[ "$line" =~ powerlevel10k\.zsh-theme ]] && return 0
  [[ "$line" =~ \.p10k\.zsh ]]            && return 0
  return 1
}

printf "${BOLD}Linting %s${RESET}\n\n" "$ZSHRC"

while IFS= read -r line || [[ -n "$line" ]]; do
  current_line=$((current_line + 1))
  trimmed="${line#"${line%%[![:space:]]*}"}"  # strip leading whitespace

  # skip blank lines and comments
  [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

  # alias declarations
  if [[ "$trimmed" =~ ^alias\ [a-zA-Z] ]]; then
    _violation "$current_line" "$trimmed" "zsh/config/aliases.zsh"
    continue
  fi

  # function definitions: "function foo" or "foo() {"
  if [[ "$trimmed" =~ ^function\ [a-zA-Z_] || "$trimmed" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\(\) ]]; then
    _violation "$current_line" "$trimmed" "zsh/config/aliases.zsh"
    continue
  fi

  # bindkey
  if [[ "$trimmed" =~ ^bindkey[[:space:]] ]]; then
    _violation "$current_line" "$trimmed" "zsh/config/keybindings.zsh"
    continue
  fi

  # export — allow structural ones
  if [[ "$trimmed" =~ ^export\ [a-zA-Z0-9_]+= ]]; then
    if ! _allowed_export "$trimmed"; then
      trimmed_upper=$(echo "$trimmed" | tr '[:lower:]' '[:upper:]')
      if [[ "$trimmed_upper" =~ (KEY|TOKEN|SECRET|PASSWORD|PASS|AUTH) ]]; then
        _violation "$current_line" "$trimmed" "pass-store"
      else
        _violation "$current_line" "$trimmed" "zsh/config/exports.zsh"
      fi
      continue
    fi
  fi

  # eval for tool inits (pyenv, rbenv, nodenv, etc.)
  if [[ "$trimmed" =~ ^eval\ .*init ]]; then
    _violation "$current_line" "$trimmed" "zsh/config/tools.zsh"
    continue
  fi

  # source calls — allow structural ones
  if [[ "$trimmed" =~ ^(source|\.\ |\[\[.*source) ]]; then
    if ! _allowed_source "$trimmed"; then
      _violation "$current_line" "$trimmed" "zsh/config/tools.zsh  (or appropriate module)"
      continue
    fi
  fi

done < "$ZSHRC"

echo ""
if [[ $violations -eq 0 ]]; then
  printf "${GREEN}✓ .zshrc is clean — no misplaced config found.${RESET}\n"
else
  printf "${RED}%d violation(s) found.${RESET} Move them to the appropriate module file in ${BOLD}zsh/config/${RESET}\n" "$violations"
fi

[[ $violations -eq 0 ]]
