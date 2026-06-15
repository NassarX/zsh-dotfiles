#!/usr/bin/env bash
# Reads .health-report.json and heals issues in three passes:
#   1. Safe fixes  — applied directly
#   2. Agent fixes — delegated to claude
#   3. Manual issues — printed + macOS notification
set -uo pipefail

export DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$DOTFILES/.health-report.json"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

if ! command -v jq &>/dev/null; then
  printf "${RED}✗${RESET}  jq not found — install with: brew install jq\n"
  exit 1
fi

if [[ ! -f "$REPORT" ]]; then
  echo "No report found. Run: bash $DOTFILES/scripts/health.sh" >&2
  exit 1
fi

_commits_before=$(git -C "$DOTFILES" rev-list --count HEAD 2>/dev/null || echo 0)

_fixed() { printf "${GREEN}✓ fixed${RESET}  %s\n" "$1"; }
_skip()  { printf "${YELLOW}⚠ skip${RESET}   %s\n" "$1"; }
_err()   { printf "${RED}✗ error${RESET}  %s\n" "$1"; }

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Pass 1: Safe fixes ───────────────────────────────────────────────────────"

safe_types=$(jq -r '[.issues[] | select(.fixable=="safe") | .type] | unique[]' "$REPORT")
safe_failed=0

if [[ -z "$safe_types" ]]; then
  echo "  (no safe issues)"
else
  for type in $safe_types; do
    issues=$(jq -c "[.issues[] | select(.fixable==\"safe\" and .type==\"$type\")]" "$REPORT")

    case "$type" in

      symlink)
        while IFS= read -r issue; do
          dest=$(jq -r '.dest' <<< "$issue")
          src=$(jq -r '.expected_src' <<< "$issue")
          mkdir -p "$(dirname "$dest")"
          ln -sf "$src" "$dest" && _fixed "symlink: $dest → $src" || { _err "failed to link $dest"; safe_failed=1; }
        done < <(jq -c '.[]' <<< "$issues")
        ;;

      local_zsh_missing)
        dest="$HOME/.config/zsh/local.zsh"
        src="$DOTFILES/zsh/local.zsh.example"
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest" && _fixed "local.zsh copied from example" || { _err "failed to copy local.zsh"; safe_failed=1; }
        ;;

      git_behind)
        git -C "$DOTFILES" pull --ff-only --quiet \
          && _fixed "dotfiles: pulled from remote" \
          || { _err "git pull failed (conflict?)"; safe_failed=1; }
        ;;

      git_ahead)
        git -C "$DOTFILES" push --quiet \
          && _fixed "dotfiles: pushed to remote" \
          || { _err "git push failed"; safe_failed=1; }
        ;;

      brew_missing)
        brew bundle install --file="$DOTFILES/Brewfile" --quiet \
          && _fixed "brew bundle: missing packages installed" \
          || { _err "brew bundle install failed"; safe_failed=1; }
        ;;

      iterm2_prefs)
        bash "$DOTFILES/scripts/setup-iterm2.sh" \
          && _fixed "iTerm2 preferences folder configured" \
          || { _err "iTerm2 setup failed"; safe_failed=1; }
        ;;

      pass_behind)
        git -C "$HOME/.password-store" pull --ff-only --quiet \
          && _fixed "pass store: pulled from remote" \
          || { _err "pass store pull failed"; safe_failed=1; }
        ;;

      pass_ahead)
        git -C "$HOME/.password-store" push --quiet \
          && _fixed "pass store: pushed to remote" \
          || { _err "pass store push failed"; safe_failed=1; }
        ;;

      lint_violation)
        while IFS= read -r issue; do
          content=$(jq -r '.content' <<< "$issue")
          target=$(jq -r '.target' <<< "$issue")

          # Extract variable name and raw value (quotes stripped, not evaluated)
          var_name=$(echo "$content" | sed -E 's/^export[[:space:]]+([a-zA-Z0-9_]+)=.*/\1/')
          var_value=$(echo "$content" | sed -E 's/^export[[:space:]]+[a-zA-Z0-9_]+=(.*)/\1/' | sed -E "s/^['\"](.*)['\"]$/\1/")

          if [[ "$target" == "pass-store" ]]; then
            if ! command -v pass &>/dev/null; then
              _skip "pass not installed — cannot auto-extract $var_name; move it to secrets.zsh manually"
              continue
            fi
            # If already a $(pass show <path>) reference, reuse that path — don't insert a new entry
            _pass_re='^\$\(pass[[:space:]]+show[[:space:]]+([^)]+)\)$'
            if [[ "$var_value" =~ $_pass_re ]]; then
              pass_path="${BASH_REMATCH[1]}"
            else
              # Plain value — insert into pass store under a derived name
              pass_path="tokens/$(echo "$var_name" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
              if ! echo "$var_value" | pass insert -f -e "$pass_path" >/dev/null; then
                _err "failed to insert $var_name into pass store at $pass_path"
                safe_failed=1
                continue
              fi
            fi

            if sed -i '' "/^[[:space:]]*} > \"\$secrets_file\"/i\\
    printf 'export ${var_name}=\"%s\"\\\\n' \"\$(pass show ${pass_path})\"
" "$DOTFILES/zsh/config/aliases.zsh" && \
               zsh -c "source $DOTFILES/zsh/config/aliases.zsh && sync-secrets" >/dev/null; then
              :
            else
              safe_failed=1
            fi
          else
            echo "$content" >> "$DOTFILES/$target" || safe_failed=1
          fi

          escaped_content=$(echo "$content" | sed 's/[]\/$*.^[]/\\&/g')
          if sed -i '' "/^$escaped_content$/d" "$DOTFILES/zsh/.zshrc"; then
            # Automatically commit the changes to your dotfiles repo
            git -C "$DOTFILES" add zsh/config/aliases.zsh zsh/.zshrc 2>/dev/null
            git -C "$DOTFILES" commit -m "feat(secrets): extract $var_name to pass store" --quiet 2>/dev/null
            _fixed "lint violation resolved: moved $var_name"
          else
            safe_failed=1
          fi
        done < <(jq -c '.[]' <<< "$issues")
        ;;

      *)
        _skip "unknown safe type: $type"
        ;;
    esac
  done
fi

if [[ "$safe_failed" -ne 0 ]]; then
  printf "${RED}✗ safe fixes failed — aborting before agent pass${RESET}\n"
  exit 1
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Pass 2: Agent fixes ──────────────────────────────────────────────────────"

# Dynamically re-check Git status to filter out stale issues resolved in Pass 1
REPORT_CLEANED=$(cat "$REPORT")
if git -C "$DOTFILES" diff-index --quiet HEAD -- 2>/dev/null; then
  REPORT_CLEANED=$(jq 'del(.issues[] | select(.type == "git_uncommitted"))' <<< "$REPORT_CLEANED")
fi
if [[ -z $(git -C "$DOTFILES" ls-files --others --exclude-standard 2>/dev/null) ]]; then
  REPORT_CLEANED=$(jq 'del(.issues[] | select(.type == "git_untracked"))' <<< "$REPORT_CLEANED")
fi

agent_issues=$(jq -c '[.issues[] | select(.fixable=="agent")]' <<< "$REPORT_CLEANED")
agent_count=$(jq 'length' <<< "$agent_issues")

if [[ "$agent_count" -eq 0 ]]; then
  echo "  (no agent issues)"
else
  echo "  $agent_count issue(s) — delegating to Claude..."

  agent_prompt=$(jq -r '
    "You are healing dotfiles issues in the repo at " + env.DOTFILES + ".\n\n" +
    "Issues to resolve:\n" +
    (.[] |
      "- [" + .type + "]: " + .fix_hint +
      (if .content then " (content: " + .content + ")" else "" end) +
      (if .target  then " (target file: " + .target  + ")" else "" end)
    ) +
    "\n\nRules:\n" +
    "1. Apply every fix directly using file-editing tools.\n" +
    "2. For lint_violation:\n" +
    "   a. If the target is 'pass-store':\n" +
    "      - Extract the variable name (e.g. CLAUDE_CODE_API_KEY) and the raw value from the .zshrc line.\n" +
    "      - Determine a clean lowercase hyphenated short name (e.g. claude-code-api-key).\n" +
    "      - Save the secret value in pass by running: echo \u0027<value>\u0027 | pass insert -f -e tokens/<short-name>\n" +
    "      - Add a corresponding mapping inside the sync-secrets function in zsh/config/aliases.zsh:\n" +
    "        printf \u0027export <VAR_NAME>=\"%s\"\\n\u0027 \"$(pass show tokens/<short-name>)\"\n" +
    "      - Run \u0027sync-secrets\u0027 to regenerate ~/.config/zsh/secrets.zsh.\n" +
    "      - Source the regenerated secrets.zsh to apply the change in the environment.\n" +
    "      - Remove the export line from .zshrc.\n" +
    "   b. Otherwise, remove the exact line from .zshrc and append it to the target module file listed in the issue.\n" +
    "3. For git_uncommitted: stage all modified tracked files and commit with a descriptive conventional commit message.\n" +
    "4. For git_untracked: if the file clearly belongs in the repo, git add and include in the commit; otherwise append its path to .gitignore.\n" +
    "5. Use conventional commit format (feat/fix/chore/docs/etc).\n" +
    "6. Do NOT push — the calling script handles that.\n" +
    "7. If you cannot safely fix an issue, print SKIPPED: <reason> and move on."
  ' <<< "$agent_issues")

  if ! command -v claude &>/dev/null; then
    _err "claude CLI not found — install Claude Code to enable agent fixes"
  else
    if claude --dangerously-skip-permissions -p "$agent_prompt"; then
      echo ""
      _fixed "Claude agent pass complete"
    else
      echo ""
      _err "Claude agent execution failed (check credits, API status, or network connection)"
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Pass 3: Manual issues ────────────────────────────────────────────────────"

manual_count=$(jq '[.issues[] | select(.fixable=="manual")] | length' "$REPORT")

if [[ "$manual_count" -eq 0 ]]; then
  echo "  (none)"
else
  jq -r '.issues[] | select(.fixable=="manual") | "  ✗ [" + .type + "] " + .fix_hint' "$REPORT"
  osascript -e "display notification \"$manual_count issue(s) need manual attention — run: bash $DOTFILES/scripts/health.sh\" with title \"dotfiles health\"" 2>/dev/null || true
fi

# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Post-heal push ───────────────────────────────────────────────────────────"

_commits_after=$(git -C "$DOTFILES" rev-list --count HEAD 2>/dev/null || echo 0)
new_commits=$(( _commits_after - _commits_before ))

if [[ "$new_commits" -gt 0 ]]; then
  git -C "$DOTFILES" push --quiet \
    && printf "${GREEN}✓ pushed${RESET}  %d new commit(s) to remote\n" "$new_commits" \
    || _err "push failed — run: cd $DOTFILES && git push"
else
  echo "  (nothing new to push)"
fi

echo ""
total_issues=$(jq '.issues | length' "$REPORT")
printf "${BOLD}Done.${RESET} %d issue(s) in last report. %d require manual attention.\n" "$total_issues" "$manual_count"
