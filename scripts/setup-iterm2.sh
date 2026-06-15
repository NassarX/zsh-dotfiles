#!/usr/bin/env bash
# First-time iTerm2 setup — captures current profile into the repo.
# Subsequent syncs happen automatically via the daily cron (daily.sh).
set -uo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Clean up any leftover DynamicProfiles file from a previous version of this setup
STALE="$HOME/Library/Application Support/iTerm2/DynamicProfiles/dotfiles-profiles.json"
if [[ -f "$STALE" || -L "$STALE" ]]; then
  rm -f "$STALE"
  printf "\033[0;33m⚠\033[0m  removed stale DynamicProfiles file\n"
fi

bash "$DOTFILES/scripts/sync-iterm2.sh"
