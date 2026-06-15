# ── editor ───────────────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"   # change to "cursor", "code", etc if you prefer a GUI editor

# ── path ─────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── language runtimes (uncomment what you use) ───────────────────────────────

# java
# export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
# export PATH="$JAVA_HOME/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── secrets (sourced from local cache — never committed) ─────────────────────
[ -f ~/.config/zsh/secrets.zsh ] && source ~/.config/zsh/secrets.zsh
