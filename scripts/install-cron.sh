#!/usr/bin/env bash
# Install the daily dotfiles health cron via launchd.
# Safe to re-run: unloads before re-linking.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.dotfiles.health"
PLIST_DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'

launchctl unload "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"

mkdir -p "$(dirname "$PLIST_DEST")"
cat <<EOF > "$PLIST_DEST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$DOTFILES/scripts/daily.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>$DOTFILES/.health-heal.log</string>
  <key>StandardErrorPath</key>
  <string>$DOTFILES/.health-heal.log</string>
  <key>RunAtLoad</key>
  <false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF

printf "${GREEN}✓${RESET} generated plist at %s\n" "$PLIST_DEST"

launchctl load "$PLIST_DEST"
printf "${GREEN}✓${RESET} launchd job loaded: ${LABEL}\n"
printf "${YELLOW}ℹ${RESET}  Runs daily at 09:00. Log: %s\n" "$DOTFILES/.health-heal.log"
