#!/usr/bin/env bash
# Track iTerm2 profile changes in git — export only, never writes to iTerm2.
# Each machine keeps its own profile file. Git history is the version log.
# To restore a previous version: git checkout <hash> -- iterm2/profiles/<machine>.json
#                                 then: bash scripts/restore-iterm2.sh
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$DOTFILES/iterm2/profiles"
SYSTEM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
MACHINE=$(scutil --get LocalHostName 2>/dev/null \
  | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
MY_PROFILE="$PROFILES_DIR/$MACHINE.json"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'
_ok()   { printf "${GREEN}✓${RESET}  iterm2: %s\n" "$1"; }
_warn() { printf "${YELLOW}⚠${RESET}  iterm2: %s\n" "$1"; }

if [[ ! -d "/Applications/iTerm.app" ]]; then
  _ok "not installed — skipping"; exit 0
fi

if [[ ! -f "$SYSTEM_PLIST" ]]; then
  _warn "no system plist found — launch iTerm2 once first"; exit 0
fi

mkdir -p "$PROFILES_DIR"

# ── Extract default profile from system plist ─────────────────────────────────
_extract_default() {
  local out="$1"
  local default_guid
  default_guid=$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null || echo "")

  plutil -extract "New Bookmarks" json -o /tmp/_iterm2_all.json "$SYSTEM_PLIST" 2>/dev/null \
    || { _warn "could not read system plist"; return 1; }

  python3 - <<PYEOF > "$out"
import json, sys

with open('/tmp/_iterm2_all.json') as f:
    profiles = json.load(f)

guid = '$default_guid'
profile = next((p for p in profiles if p.get('Guid') == guid), None) or (profiles[0] if profiles else None)
if not profile:
    sys.exit(1)

for key in ('Keyboard Map', 'Bound Hosts'):
    profile.pop(key, None)

print(json.dumps(profile, indent=2))
PYEOF
}

if ! _extract_default /tmp/_iterm2_current.json; then
  _warn "could not extract default profile — skipping"; exit 0
fi

# ── First time on this machine: save and commit ───────────────────────────────
if [[ ! -f "$MY_PROFILE" ]]; then
  python3 - <<PYEOF
import json, subprocess

with open('/tmp/_iterm2_current.json') as f:
    profile = json.load(f)

profile['Name'] = '$MACHINE'
profile['Guid'] = subprocess.check_output(['uuidgen']).decode().strip()

with open('$MY_PROFILE', 'w') as f:
    json.dump(profile, f, indent=2)
PYEOF
  git -C "$DOTFILES" add "$MY_PROFILE"
  git -C "$DOTFILES" commit -m "feat(iterm2): add profile for $MACHINE" --quiet 2>/dev/null
  _ok "first capture — committed $MACHINE profile"
  exit 0
fi

# ── Compare and commit if changed ─────────────────────────────────────────────
changed=$(python3 - <<PYEOF
import json

def stripped(path):
    with open(path) as f:
        p = json.load(f)
    for k in ('Name', 'Guid', 'Keyboard Map', 'Bound Hosts'):
        p.pop(k, None)
    return p

print('changed' if stripped('/tmp/_iterm2_current.json') != stripped('$MY_PROFILE') else 'same')
PYEOF
)

if [[ "$changed" == "changed" ]]; then
  python3 - <<PYEOF
import json

with open('/tmp/_iterm2_current.json') as f:
    current = json.load(f)
with open('$MY_PROFILE') as f:
    saved = json.load(f)

current['Name'] = saved['Name']
current['Guid'] = saved['Guid']
for k in ('Keyboard Map', 'Bound Hosts'):
    current.pop(k, None)

with open('$MY_PROFILE', 'w') as f:
    json.dump(current, f, indent=2)
PYEOF
  git -C "$DOTFILES" add "$MY_PROFILE"
  git -C "$DOTFILES" commit -m "chore(iterm2): sync $MACHINE profile" --quiet 2>/dev/null
  _ok "profile changed — committed $MACHINE"
else
  _ok "no changes ($MACHINE)"
fi
