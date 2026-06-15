#!/usr/bin/env bash
# Daily dotfiles maintenance — runs via launchd at 09:00.
# Order matters: pull first so sync and health see the latest repo state.
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "── $(date '+%Y-%m-%d %H:%M') ────────────────────────────────────────────────────"

# 1. Pull latest dotfiles before anything else
echo "── Pull ─────────────────────────────────────────────────────────────────────"
git -C "$DOTFILES" pull --ff-only --quiet 2>/dev/null \
  && echo "  ✓ dotfiles up to date" \
  || echo "  ⚠ pull failed (conflict or offline) — continuing with local state"

# 2. Sync iTerm2 profile for this machine
echo "── iTerm2 ───────────────────────────────────────────────────────────────────"
bash "$DOTFILES/scripts/sync-iterm2.sh" || true

# 3. Health check → writes .health-report.json
echo "── Health ───────────────────────────────────────────────────────────────────"
bash "$DOTFILES/scripts/health.sh" || true

# 4. Heal what can be healed (push, brew, symlinks, etc.)
echo "── Heal ─────────────────────────────────────────────────────────────────────"
bash "$DOTFILES/scripts/heal.sh" || true
