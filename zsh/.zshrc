# ── p10k instant prompt (MUST be first) ──────────────────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── homebrew ──────────────────────────────────────────────────────────────────
export PATH="/opt/homebrew/bin:$PATH"

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_DISABLE_COMPFIX=true
ENABLE_CORRECTION="true"
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7
plugins=(git zoxide zsh-autosuggestions fast-syntax-highlighting zsh-autocomplete)
source $ZSH/oh-my-zsh.sh

# ── modular config ────────────────────────────────────────────────────────────
for f in ~/.config/zsh/*.zsh; do source "$f"; done

# ── iterm2 ────────────────────────────────────────────────────────────────────
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# ── p10k theme + config (MUST be at bottom) ───────────────────────────────────
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
