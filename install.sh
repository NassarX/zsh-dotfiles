#!/usr/bin/env bash
# Bootstrap a fresh Mac to a fully configured dev environment.
# Idempotent — safe to re-run at any time.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'

_ok()   { printf "${GREEN}✓${RESET}  %s\n" "$1"; }
_skip() { printf "${YELLOW}⚠${RESET}  %s — skipping\n" "$1"; }
_fail() { printf "${RED}✗${RESET}  %s\n" "$1"; exit 1; }

# ── 0. Backup ─────────────────────────────────────────────────────────────────
backup_existing_config() {
  local targets=(
    "$HOME/.zshrc"
    "$HOME/.gitconfig"
    "$HOME/.p10k.zsh"
    "$HOME/.config/zsh"
    "$HOME/.config/bat/config"
  )

  local has_files=0
  for t in "${targets[@]}"; do
    [[ -e "$t" && ! -L "$t" ]] && has_files=1 && break
  done
  [[ "$has_files" -eq 0 ]] && return 0

  local backup="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup"

  for t in "${targets[@]}"; do
    [[ -e "$t" && ! -L "$t" ]] && cp -r "$t" "$backup/"
  done

  _ok "existing config backed up to $backup"
  printf "    To restore: bash %s/scripts/restore-backup.sh\n" "$DOTFILES"
}

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
check_prerequisites() {
  [[ "$(uname)" == "Darwin" ]] || _fail "macOS only"
  command -v git &>/dev/null    || _fail "git not found — install Xcode CLI tools first"
  curl -s --head https://example.com &>/dev/null || _fail "no internet connection"
  _ok "prerequisites"
}

# ── 2. Xcode CLI tools ────────────────────────────────────────────────────────
install_xcode_tools() {
  if xcode-select -p &>/dev/null; then
    _skip "Xcode CLI tools already installed"
  else
    xcode-select --install
    _ok "Xcode CLI tools installed — re-run this script after installation completes"
    exit 0
  fi
}

# ── 3. Homebrew ───────────────────────────────────────────────────────────────
install_homebrew() {
  if command -v brew &>/dev/null; then
    _skip "Homebrew already installed"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)" || _fail "brew shellenv failed"
    _ok "Homebrew installed"
  fi
}

# ── 4. Brew bundle ────────────────────────────────────────────────────────────
brew_bundle() {
  [[ -f "$DOTFILES/Brewfile" ]] || _fail "Brewfile not found at $DOTFILES/Brewfile"
  brew bundle --file="$DOTFILES/Brewfile" || _fail "brew bundle failed"
  _ok "Homebrew packages installed"
}

# ── 5. oh-my-zsh ─────────────────────────────────────────────────────────────
install_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    _skip "oh-my-zsh already installed"
  else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    _ok "oh-my-zsh installed"
  fi
}

# ── 6. zsh plugins ────────────────────────────────────────────────────────────
install_zsh_plugins() {
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
    _ok "zsh-autosuggestions installed"
  else
    _skip "zsh-autosuggestions already installed"
  fi

  if [[ ! -d "$custom/plugins/fast-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting "$custom/plugins/fast-syntax-highlighting"
    _ok "fast-syntax-highlighting installed"
  else
    _skip "fast-syntax-highlighting already installed"
  fi

  if [[ ! -d "$custom/plugins/zsh-autocomplete" ]]; then
    git clone --depth=1 https://github.com/marlonrichert/zsh-autocomplete "$custom/plugins/zsh-autocomplete"
    _ok "zsh-autocomplete installed"
  else
    _skip "zsh-autocomplete already installed"
  fi
}

# ── 7. Existing config check ──────────────────────────────────────────────────
check_existing_config() {
  local conflicts=()
  [[ -f "$HOME/.zshrc"             && ! -L "$HOME/.zshrc"             ]] && conflicts+=("~/.zshrc")
  [[ -f "$HOME/.gitconfig"         && ! -L "$HOME/.gitconfig"         ]] && conflicts+=("~/.gitconfig")
  [[ -f "$HOME/.p10k.zsh"          && ! -L "$HOME/.p10k.zsh"          ]] && conflicts+=("~/.p10k.zsh")
  [[ -d "$HOME/.config/zsh"        && ! -L "$HOME/.config/zsh"        ]] && conflicts+=("~/.config/zsh/")
  [[ -f "$HOME/.config/bat/config" && ! -L "$HOME/.config/bat/config" ]] && conflicts+=("~/.config/bat/config")

  [[ ${#conflicts[@]} -eq 0 ]] && return 0

  echo ""
  printf "${YELLOW}⚠  Existing config detected:${RESET}\n"
  for f in "${conflicts[@]}"; do printf "   %s\n" "$f"; done
  echo ""
  echo "   [m] Migrate  — move your aliases, exports, keys, and secrets into"
  echo "                  the right module files automatically, then switch over"
  echo "   [r] Replace  — back up existing files and replace with dotfiles"
  echo "   [a] Abort    — exit without changing anything"
  echo ""
  read -rp "   Choice [m/r/a]: " answer
  case "${answer,,}" in
    m)
      bash "$DOTFILES/scripts/migrate.sh"
      ;;
    r)
      local backup="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
      mkdir -p "$backup"
      for target in "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.p10k.zsh" \
                    "$HOME/.config/zsh" "$HOME/.config/bat/config"; do
        [[ -e "$target" && ! -L "$target" ]] && cp -r "$target" "$backup/" && rm -rf "$target"
      done
      _ok "backed up existing files to $backup"
      ;;
    *)
      echo "Aborted."
      exit 0
      ;;
  esac
}

# ── 8. Symlinks ───────────────────────────────────────────────────────────────
create_symlinks() {
  bash "$DOTFILES/scripts/link.sh"
  _ok "symlinks created"
}

# ── 8. gitconfig ─────────────────────────────────────────────────────────────
setup_gitconfig() {
  local dest="$DOTFILES/git/.gitconfig"
  local current_name current_email
  current_name=$(git config --file "$dest" user.name  2>/dev/null || true)
  current_email=$(git config --file "$dest" user.email 2>/dev/null || true)

  if [[ "$current_name" != "Your Name" && -n "$current_name" ]]; then
    _skip "git/.gitconfig already has identity: $current_name <$current_email>"
    return
  fi

  local global_name global_email
  global_name=$(git config --global user.name  2>/dev/null || true)
  global_email=$(git config --global user.email 2>/dev/null || true)

  if [[ -n "$global_name" && -n "$global_email" ]]; then
    git config --file "$dest" user.name  "$global_name"
    git config --file "$dest" user.email "$global_email"
    _ok "git identity set from global config: $global_name <$global_email>"
    return
  fi

  echo ""
  read -rp "   Git name  (e.g. Jane Smith): "  git_name
  read -rp "   Git email (e.g. jane@example.com): " git_email

  [[ -n "$git_name"  ]] && git config --file "$dest" user.name  "$git_name"
  [[ -n "$git_email" ]] && git config --file "$dest" user.email "$git_email"

  _ok "git identity set: $git_name <$git_email>"
}

# ── 9. local.zsh ─────────────────────────────────────────────────────────────
setup_local_zsh() {
  local target="$HOME/.config/zsh/local.zsh"
  if [[ -f "$target" ]]; then
    _skip "local.zsh already exists at $target"
  else
    mkdir -p "$(dirname "$target")"
    cp "$DOTFILES/zsh/local.zsh.example" "$target"
    _ok "local.zsh created — fill in machine-specific values: $target"
  fi
}

# ── 10. pass + GPG (optional) ─────────────────────────────────────────────────
setup_secrets() {
  echo ""
  printf "${YELLOW}ℹ${RESET}  Secrets setup uses GPG + pass to keep tokens out of the repo.\n"
  read -rp "   Set up pass store now? [y/N]: " answer
  if [[ "${answer,,}" != "y" ]]; then
    _skip "secrets setup — using plain secrets.zsh instead"
    local secrets_file="$HOME/.config/zsh/secrets.zsh"
    if [[ ! -f "$secrets_file" ]]; then
      mkdir -p "$(dirname "$secrets_file")"
      cp "$DOTFILES/zsh/config/secrets.example.zsh" "$secrets_file"
      printf "${YELLOW}▶${RESET}  Fill in your secrets at: %s\n" "$secrets_file"
    fi
    return
  fi

  command -v pass &>/dev/null || _fail "pass not installed — check Brewfile"
  command -v gpg  &>/dev/null || _fail "gnupg not installed — check Brewfile"

  read -rp "Import GPG key? Enter path to .asc file (or press Enter to skip): " asc_path
  if [[ -n "$asc_path" ]]; then
    gpg --import "$asc_path" || _fail "GPG import failed"
    _ok "GPG key imported"
  else
    _skip "GPG key import"
  fi

  if [[ -d "$HOME/.password-store" ]]; then
    _skip "pass store already exists"
  else
    read -rp "Pass store repo URL (or Enter to init fresh): " pass_url
    if [[ -n "$pass_url" ]]; then
      git clone "$pass_url" "$HOME/.password-store" || _fail "pass store clone failed"
      _ok "pass store cloned"
    else
      read -rp "GPG key ID to initialize pass with: " gpg_id
      pass init "$gpg_id" || _fail "pass init failed"
      _ok "pass store initialized"
    fi
  fi
}

# ── 11. sync-secrets ──────────────────────────────────────────────────────────
run_sync_secrets() {
  if command -v pass &>/dev/null && [[ -d "$HOME/.password-store" ]]; then
    source "$DOTFILES/zsh/config/aliases.zsh"
    sync-secrets 2>/dev/null && _ok "secrets synced" || \
      _skip "sync-secrets failed — add your entries to zsh/config/aliases.zsh then run: sync-secrets"
  else
    _skip "pass not ready — run 'sync-secrets' after setting up your pass store"
  fi
}

# ── 12. iTerm2 ───────────────────────────────────────────────────────────────
setup_iterm2() {
  bash "$DOTFILES/scripts/setup-iterm2.sh"
}

# ── 13. git hooks ────────────────────────────────────────────────────────────
install_git_hooks() {
  bash "$DOTFILES/scripts/install-hooks.sh"
  _ok "git hooks installed"
}

# ── 14. health cron ──────────────────────────────────────────────────────────
install_health_cron() {
  bash "$DOTFILES/scripts/install-cron.sh"
  _ok "daily health cron installed"
}

# ── 15. default shell ────────────────────────────────────────────────────────
set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" == "$zsh_path" ]]; then
    _skip "zsh already default shell"
  else
    chsh -s "$zsh_path" || _fail "chsh failed"
    _ok "default shell set to zsh"
  fi
}

# ── 16. Summary ──────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  printf '%sBootstrap complete.%s\n' "$GREEN" "$RESET"
  echo ""
  echo "Next steps:"
  echo "  1. Edit git/.gitconfig with your name and email (if not done)"
  echo "  2. Fill in ~/.config/zsh/local.zsh with any machine-specific paths"
  echo "  3. Add your secrets to zsh/config/aliases.zsh → sync-secrets function"
  echo "  4. Run: sync-secrets"
  echo "  5. Open a new terminal — you should see the Powerlevel10k prompt"

  if [[ ! -f "$DOTFILES/zsh/.p10k.zsh" || ! -s "$DOTFILES/zsh/.p10k.zsh" ]]; then
    echo ""
    printf "${YELLOW}  ⚠  Powerlevel10k is not configured yet.${RESET}\n"
    echo "     Open a new terminal and run: p10k configure"
    echo "     This saves your prompt config to zsh/.p10k.zsh — commit and push"
    echo "     so all your machines get the same prompt."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
backup_existing_config
check_prerequisites
install_xcode_tools
install_homebrew
brew_bundle
install_omz
install_zsh_plugins
setup_gitconfig
check_existing_config
create_symlinks
setup_local_zsh
setup_secrets
run_sync_secrets
setup_iterm2
install_git_hooks
install_health_cron
set_default_shell
print_summary
