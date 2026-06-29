#!/usr/bin/env bash
# Full dotfiles environment health check.
# Checks: symlinks, git sync, Brewfile drift, stale Brewfile entries,
#         broken skill symlinks, secrets, shell load.
# Exit code: 0 = all OK, 1 = issues found.
set -uo pipefail

if ! command -v jq &>/dev/null; then
  printf "\033[0;31m✗\033[0m  jq not found — install with: brew install jq\n"
  exit 1
fi

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'
ISSUES=0

REPORT_FILE="$DOTFILES/.health-report.json"
declare -a _ISSUES=()

_issue() {
  local type="$1" status="$2" fixable="$3" fix_hint="$4" extra="${5:-}"
  local obj
  obj=$(jq -n \
    --arg type    "$type"    \
    --arg status  "$status"  \
    --arg fixable "$fixable" \
    --arg hint    "$fix_hint" \
    '{type:$type, status:$status, fixable:$fixable, fix_hint:$hint}')
  if [[ -n "$extra" ]]; then
    obj=$(jq -n --argjson base "$obj" --argjson extra "$extra" '$base + $extra')
  fi
  _ISSUES+=("$obj")
}

_write_report() {
  local ts issues_json
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if [[ ${#_ISSUES[@]} -eq 0 ]]; then
    issues_json="[]"
  else
    issues_json=$(printf '%s\n' "${_ISSUES[@]}" | jq -s '.')
  fi
  jq -n \
    --arg ts "$ts" \
    --argjson issues "$issues_json" \
    '{generated_at:$ts, issues:$issues}' > "$REPORT_FILE"
}

_ok()   { printf "${GREEN}✓${RESET}  %s\n" "$1"; }
_warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$1"; ISSUES=$((ISSUES + 1)); }
_fail() { printf "${RED}✗${RESET}  %s\n" "$1"; ISSUES=$((ISSUES + 1)); }

echo "── Symlinks ─────────────────────────────────────────────────────────────────"

check_symlink() {
  local dest="$1" expected_src="$2"
  local actual_src
  actual_src="$(readlink "$dest" 2>/dev/null || true)"
  if [[ "$actual_src" == "$expected_src" ]]; then
    _ok "$dest"
  else
    _fail "$dest → expected $expected_src, got: ${actual_src:-<not a symlink>}"
    _issue "symlink" "fail" "safe" "ln -sf $expected_src $dest" \
      "$(jq -n --arg dest "$dest" --arg src "$expected_src" '{dest:$dest,expected_src:$src}')"
  fi
}

check_symlink "$HOME/.zshrc"              "$DOTFILES/zsh/.zshrc"
check_symlink "$HOME/.p10k.zsh"           "$DOTFILES/zsh/.p10k.zsh"
check_symlink "$HOME/.config/zsh"         "$DOTFILES/zsh/config"
check_symlink "$HOME/.gitconfig"          "$DOTFILES/git/.gitconfig"
check_symlink "$HOME/.config/bat/config"  "$DOTFILES/bat/config"

echo ""
echo "── Brewfile drift ───────────────────────────────────────────────────────────"

if command -v brew &>/dev/null; then
  if brew bundle check --file="$DOTFILES/Brewfile" &>/dev/null; then
    _ok "all Brewfile packages installed"
  else
    _warn "Brewfile packages missing — run: brew bundle --file=$DOTFILES/Brewfile"
    brew bundle check --file="$DOTFILES/Brewfile" 2>&1 | grep "^x " | sed 's/^/    /'
    _issue "brew_missing" "warn" "safe" "brew bundle install --file=$DOTFILES/Brewfile"
  fi
  # Stale: in Brewfile but not installed (uninstalled without updating Brewfile)
  stale_formulae=()
  while IFS= read -r formula; do
    [[ -z "$formula" ]] && continue
    brew list --formula "$formula" &>/dev/null || stale_formulae+=("$formula")
  done < <(grep '^brew ' "$DOTFILES/Brewfile" 2>/dev/null | sed 's/brew "\([^"]*\)".*/\1/')
  if [[ ${#stale_formulae[@]} -eq 0 ]]; then
    _ok "no stale Brewfile entries"
  else
    _warn "${#stale_formulae[@]} stale formula(e) in Brewfile not installed: ${stale_formulae[*]}"
    stale_json=$(printf '%s\n' "${stale_formulae[@]}" | jq -R . | jq -s .)
    _issue "brew_stale" "warn" "safe" "remove stale formulae from Brewfile" \
      "$(jq -n --argjson f "$stale_json" '{formulae:$f}')"
  fi
else
  _fail "brew not found — Homebrew not installed"
  _issue "brew_not_installed" "fail" "manual" "install Homebrew from https://brew.sh"
fi

echo ""
echo "── Broken symlinks ──────────────────────────────────────────────────────────"

_broken_total=0
_broken_paths=()
while IFS= read -r _dir; do
  while IFS= read -r _link; do
    _broken_paths+=("$_link")
    _broken_total=$((_broken_total + 1))
  done < <(find "$_dir" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)
done < <(find "$HOME" -maxdepth 3 -type d -name "skills" 2>/dev/null)

if [[ $_broken_total -eq 0 ]]; then
  _ok "no broken symlinks in skill dirs"
else
  _warn "$_broken_total broken symlink(s) in skill dirs"
  _broken_json=$(printf '%s\n' "${_broken_paths[@]}" | jq -R . | jq -s .)
  _issue "broken_symlinks" "warn" "safe" "delete $_broken_total broken symlinks in skill dirs" \
    "$(jq -n --argjson p "$_broken_json" '{paths:$p}')"
fi

echo ""
echo "── Secrets ──────────────────────────────────────────────────────────────────"

secrets_zsh="$HOME/.config/zsh/secrets.zsh"
if [[ ! -f "$secrets_zsh" ]]; then
  _warn "secrets.zsh missing — run: sync-secrets  (or copy zsh/config/secrets.example.zsh → $secrets_zsh)"
  _issue "secrets_zsh_missing" "warn" "manual" "copy secrets.example.zsh or run sync-secrets"
else
  age_days=$(( ( $(date +%s) - $(stat -f %m "$secrets_zsh" 2>/dev/null || echo 0) ) / 86400 ))
  if [[ $age_days -gt 30 ]]; then
    _warn "secrets.zsh is ${age_days} days old — consider running: sync-secrets"
    _issue "secrets_zsh_stale" "warn" "manual" "run sync-secrets" \
      "$(jq -n --argjson d "$age_days" '{age_days:$d}')"
  else
    _ok "secrets.zsh present (${age_days} days old)"
  fi
fi

if command -v pass &>/dev/null; then
  if [[ -d "$HOME/.password-store" ]]; then
    pass_ahead=$(git -C "$HOME/.password-store" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    pass_behind=$(git -C "$HOME/.password-store" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    [[ "$pass_ahead"  -eq 0 ]] && _ok "pass store: nothing to push"  || { _warn "pass store: $pass_ahead commit(s) unpushed";     _issue "pass_ahead"  "warn" "safe" "git -C $HOME/.password-store push"; }
    [[ "$pass_behind" -eq 0 ]] && _ok "pass store: up to date"       || { _warn "pass store: $pass_behind commit(s) to pull";     _issue "pass_behind" "warn" "safe" "git -C $HOME/.password-store pull --ff-only"; }
  else
    _warn "pass installed but no store at ~/.password-store — run: pass init <gpg-id>"
    _issue "pass_not_found" "warn" "manual" "run: pass init <gpg-key-id>"
  fi
else
  _ok "pass not installed — using plain secrets.zsh (no sync check needed)"
fi

echo ""
echo "── iTerm2 ───────────────────────────────────────────────────────────────────"

if [[ -d "/Applications/iTerm.app" ]]; then
  MACHINE=$(scutil --get LocalHostName 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
  MY_PROFILE="$DOTFILES/iterm2/profiles/$MACHINE.json"
  if [[ ! -f "$MY_PROFILE" ]]; then
    _warn "iTerm2 profile for $MACHINE not captured yet — run: bash $DOTFILES/scripts/sync-iterm2.sh"
    _issue "iterm2_prefs" "warn" "safe" "bash $DOTFILES/scripts/sync-iterm2.sh"
  else
    _ok "iTerm2 profile tracked ($MACHINE)"
  fi
else
  _ok "iTerm2 not installed — skipping"
fi

echo ""
echo "── Shell load ───────────────────────────────────────────────────────────────"

if zsh -i -c 'exit 0' 2>/dev/null; then
  _ok "zsh loads without errors"
else
  _fail "zsh startup produced errors — run: zsh -i -c 'exit 0' to see them"
  _issue "zsh_errors" "fail" "manual" "run: zsh -i -c 'exit 0' to diagnose"
fi

if [[ -f "$HOME/.config/zsh/local.zsh" ]]; then
  _ok "local.zsh present"
else
  _warn "local.zsh missing — copy from: $DOTFILES/zsh/local.zsh.example"
  _issue "local_zsh_missing" "warn" "safe" "cp $DOTFILES/zsh/local.zsh.example $HOME/.config/zsh/local.zsh"
fi

p10k_file="$DOTFILES/zsh/.p10k.zsh"
if [[ ! -f "$p10k_file" || ! -s "$p10k_file" ]]; then
  _warn "Powerlevel10k not configured — run: p10k configure"
  _issue "p10k_unconfigured" "warn" "manual" "run: p10k configure"
else
  _ok "Powerlevel10k configured"
fi

echo ""
echo "── .zshrc lint ──────────────────────────────────────────────────────────────"

lint_output=$(bash "$DOTFILES/scripts/lint-zshrc.sh" "$DOTFILES/zsh/.zshrc" 2>/dev/null || true)
lint_output=$(echo "$lint_output" | sed 's/\x1b\[[0-9;]*m//g')

if echo "$lint_output" | grep -q "✓"; then
  _ok ".zshrc is clean"
else
  violations_count=$(echo "$lint_output" | grep -c "✗" || true)
  _warn "$violations_count misplaced line(s) in .zshrc — run: bash $DOTFILES/scripts/lint-zshrc.sh"

  # Parse violations structurally: each violation is a "✗ line N  <content>" line
  # immediately followed by a "→ move to: <target>" line.
  prev_content=""
  prev_lineno=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^✗[[:space:]]+line[[:space:]]+([0-9]+)[[:space:]]+(.*) ]]; then
      prev_lineno="${BASH_REMATCH[1]}"
      prev_content="${BASH_REMATCH[2]}"
    elif [[ -n "$prev_content" && "$line" =~ →[[:space:]]+move\ to:[[:space:]]+(.*) ]]; then
      target="${BASH_REMATCH[1]}"
      _issue "lint_violation" "warn" "safe" "move to $target" \
        "$(jq -n --arg ln "$prev_lineno" --arg c "$prev_content" --arg t "$target" \
          '{line:$ln,content:$c,target:$t}')"
      prev_content=""
      prev_lineno=""
    fi
  done <<< "$lint_output"
fi
echo ""
echo "── Git sync ─────────────────────────────────────────────────────────────────"

# Uncommitted changes
if git -C "$DOTFILES" diff-index --quiet HEAD -- 2>/dev/null; then
  _ok "no uncommitted changes"
else
  _warn "uncommitted changes in $DOTFILES — run: cd $DOTFILES && git status"
  _issue "git_uncommitted" "warn" "agent" "uncommitted changes in $DOTFILES"
fi

# Untracked files (excluding gitignored)
untracked=$(git -C "$DOTFILES" ls-files --others --exclude-standard 2>/dev/null)
if [[ -z "$untracked" ]]; then
  _ok "no untracked files"
else
  _warn "untracked files in $DOTFILES:"
  echo "$untracked" | sed 's/^/    /'
  _issue "git_untracked" "warn" "agent" "untracked files: $(echo "$untracked" | tr '\n' ' ')"
fi

# Ahead/behind remote
git -C "$DOTFILES" fetch --quiet 2>/dev/null || _warn "could not fetch remote (offline?)"
ahead=$(git -C "$DOTFILES" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
[[ "$ahead" =~ ^[0-9]+$ ]] || ahead=0
behind=$(git -C "$DOTFILES" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
[[ "$behind" =~ ^[0-9]+$ ]] || behind=0
[[ "$ahead"  -eq 0 ]] && _ok "nothing to push"        || { _warn "$ahead commit(s) to push — run: cd $DOTFILES && git push";  _issue "git_ahead"  "warn" "safe" "git -C $DOTFILES push"            "$(jq -n --argjson c "$ahead"  '{count:$c}')"; }
[[ "$behind" -eq 0 ]] && _ok "up to date with remote" || { _warn "$behind commit(s) to pull — run: cd $DOTFILES && git pull"; _issue "git_behind" "warn" "safe" "git -C $DOTFILES pull --ff-only" "$(jq -n --argjson c "$behind" '{count:$c}')"; }

echo ""
_write_report

if [[ $ISSUES -eq 0 ]]; then
  printf "%sAll checks passed.%s\n" "$GREEN" "$RESET"
else
  printf "%s%d issue(s) found. See warnings above.%s\n" "$YELLOW" "$ISSUES" "$RESET"
fi

[[ $ISSUES -eq 0 ]]
