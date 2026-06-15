#!/usr/bin/env bash
# Apply the repo profile back to iTerm2's system plist.
# Use this to restore a previous version after: git checkout <hash> -- iterm2/profiles/<machine>.json
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$DOTFILES/iterm2/profiles"
SYSTEM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
MACHINE=$(scutil --get LocalHostName 2>/dev/null \
  | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
MY_PROFILE="$PROFILES_DIR/$MACHINE.json"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'
_ok()   { printf "${GREEN}✓${RESET}  %s\n" "$1"; }
_warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$1"; }
_fail() { printf "${RED}✗${RESET}  %s\n" "$1"; exit 1; }

[[ -f "$MY_PROFILE" ]]   || _fail "no profile found for $MACHINE at $MY_PROFILE"
[[ -f "$SYSTEM_PLIST" ]] || _fail "iTerm2 system plist not found — launch iTerm2 once first"

# Merge repo profile into system plist (replace matching Guid, or append)
python3 - <<PYEOF
import json, subprocess, sys

with open('$MY_PROFILE') as f:
    repo_profile = json.load(f)

result = subprocess.run(
    ['plutil', '-extract', 'New Bookmarks', 'json', '-o', '-', '$SYSTEM_PLIST'],
    capture_output=True, text=True
)
if result.returncode != 0:
    print('could not read system plist', file=sys.stderr)
    sys.exit(1)

profiles = json.loads(result.stdout)
guid = repo_profile.get('Guid', '')
idx = next((i for i, p in enumerate(profiles) if p.get('Guid') == guid), None)

if idx is not None:
    profiles[idx] = repo_profile
else:
    profiles.append(repo_profile)

merged_json = json.dumps(profiles)
result = subprocess.run(
    ['plutil', '-replace', 'New Bookmarks', '-json', merged_json, '$SYSTEM_PLIST'],
    capture_output=True
)
if result.returncode != 0:
    print('failed to write system plist', file=sys.stderr)
    sys.exit(1)
PYEOF

_ok "profile restored — restart iTerm2 to apply"
_warn "to undo: git checkout HEAD -- iterm2/profiles/$MACHINE.json && bash scripts/restore-iterm2.sh"
