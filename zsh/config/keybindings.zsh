# ── edit command in $EDITOR ───────────────────────────────────────────────────
autoload -z edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ── word navigation (requires iTerm2 Left Option → Esc+) ─────────────────────
bindkey '^[[1;3C' forward-word       # Option+→
bindkey '^[[1;3D' backward-word      # Option+←
bindkey '^[^?'    backward-kill-word # Option+Backspace

# ── ctrl-z toggle (suspend / fg) ─────────────────────────────────────────────
function _ctrl_z() {
  if [[ $#BUFFER -eq 0 ]]; then fg; else zle push-input; fi
}
zle -N _ctrl_z
bindkey '^Z' _ctrl_z

# ── ctrl-f: fzf directory jump (ALT-C fallback for Apple keyboard) ────────────
bindkey -s '^F' 'cd $(fd --type d --hidden --exclude .git | fzf --preview "tree -C {} | head -50")\n'
