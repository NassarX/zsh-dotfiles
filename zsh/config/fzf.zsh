source <(fzf --zsh)   # enables CTRL-T, CTRL-R, ALT-C

# fd as default source — faster than find, respects .gitignore
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'

export FZF_DEFAULT_OPTS="
  --style full
  --layout reverse
  --border rounded
  --height 80%
  --padding 1
  --info inline-right
  --color 'border:#aaaaaa,label:#cccccc,header:italic'
"

# CTRL-T: file picker with bat preview
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --line-range :200 {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
"

# CTRL-R: history — CTRL-Y copies to clipboard
export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'CTRL-Y → copy to clipboard'
"

# ALT-C: directory jump with tree preview
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target,.next,dist
  --preview 'tree -C {} | head -50'
"
