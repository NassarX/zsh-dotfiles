#!/usr/bin/env bash
# Install git hooks for this repo.
# Safe to re-run — overwrites existing hooks.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$DOTFILES/.git/hooks"
GREEN='\033[0;32m'; RESET='\033[0m'

cat > "$HOOKS_DIR/pre-commit" <<'EOF'
#!/usr/bin/env bash
# Lint .zshrc before every commit.
DOTFILES="$(git rev-parse --show-toplevel)"
if git diff --cached --name-only | grep -q "zsh/.zshrc"; then
  echo "── zshrc lint ───────────────────────────────────────────────────────────────"
  bash "$DOTFILES/scripts/lint-zshrc.sh" "$DOTFILES/zsh/.zshrc"
  exit $?
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"
printf "${GREEN}✓${RESET} pre-commit hook installed at %s\n" "$HOOKS_DIR/pre-commit"
