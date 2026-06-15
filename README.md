# zsh-dotfiles

> Every time I got a new Mac, I spent half a day rebuilding what I had — missing aliases, wrong prompt, tokens to re-enter, packages to reinstall. I built this to make that problem disappear. Now I clone one repo, run one command, and I'm back to exactly where I left off.

---

## What it promises

- **One command setup** — run `install.sh` on any Mac and get a fully configured environment
- **Your existing config is safe** — backs up everything before touching it, migrates your aliases and exports automatically
- **Works whether you have a `.zshrc` or a bare shell** — detects your current state and does the right thing
- **Syncs overnight** — change something on one machine, it's on all your machines by morning
- **Secrets never touch git** — tokens stay encrypted in a pass store with its own private remote
- **Self-healing** — a daily job catches drift (broken symlinks, missing packages, git falling behind) and fixes it silently

---

## Before / After

**Before** — a `.zshrc` that grew for years, or a shell with nothing at all:

```zsh
# ~/.zshrc — the typical accumulated mess
export PATH="/opt/homebrew/bin:$PATH"
export GITHUB_PAT="ghp_abc123..."        # hardcoded secret
export OPENAI_API_KEY="sk-..."           # another one
alias gs="git status"
alias fe='$EDITOR $(fzf)'
eval "$(pyenv init --path)"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# ... 200 more lines
```

```zsh
# Or: a brand new Mac with nothing configured
$ echo $SHELL
/bin/zsh
$ ls ~/.zshrc
ls: /Users/you/.zshrc: No such file or directory
```

**After** — `.zshrc` becomes a loader, everything in its place:

```
~/.zshrc  →  zsh/.zshrc           # 20 lines — just sources the modules
              zsh/config/
                aliases.zsh        # all your aliases and functions
                exports.zsh        # PATH and environment variables
                tools.zsh          # pyenv, nvm, bun init
                secrets.zsh        # GITIGNORED — generated from encrypted store
                local.zsh          # GITIGNORED — machine-specific paths
```

Secrets are out of plain text files. Config is organized. Everything is committed and versioned. Whether you had 300 lines of shell config or zero — you end up in the same clean state.

---

## What you get

| Feature | Details |
|---|---|
| Prompt | Powerlevel10k — git status, runtime, exit code |
| Completions | zsh-autocomplete + zsh-autosuggestions |
| Syntax highlighting | fast-syntax-highlighting |
| Directory jump | zoxide — `z projects` jumps to frecent dirs |
| Fuzzy everything | fzf + fd + bat — files, history, branches, processes |
| Secrets | pass + GPG (optional) — encrypted, synced, never in git |
| iTerm2 profiles | per-machine profile tracked in git, full history |
| Daily maintenance | launchd cron — pull, sync, heal, push at 09:00 |

---

## Install

### Existing machine (with `.zshrc` or shell config)

```bash
# Fork this repo on GitHub (make it private)
git clone git@github.com:you/zsh-dotfiles ~/.dotfiles
cd ~/.dotfiles
bash install.sh
```

Your existing files are backed up to `~/.dotfiles-backup/<timestamp>/` before anything changes.

When it detects your existing config it asks:

```
⚠  Existing config detected: ~/.zshrc  ~/.gitconfig  ~/.config/zsh/

   [m] Migrate  — parse your files and distribute into the right modules
   [r] Replace  — back up everything and start from the repo defaults
   [a] Abort    — exit without changing anything
```

Choose **`m`**. It parses your `.zshrc` line by line — aliases go to `aliases.zsh`, exports to `exports.zsh`, anything that looks like a secret goes to a separate gitignored file. Review what landed where, remove duplicates, then commit and push.

### Fresh machine (nothing configured)

```bash
git clone git@github.com:you/zsh-dotfiles ~/.dotfiles
cd ~/.dotfiles
bash install.sh
```

No existing config detected — installs straight through. Homebrew, oh-my-zsh, plugins, symlinks, secrets setup, cron — all in one run. Open a new terminal and you have a fully working environment.

### New machine pulling your existing setup

```bash
# If you use pass+GPG, import your key first
gpg --import key.asc && rm key.asc

git clone git@github.com:you/zsh-dotfiles ~/.dotfiles
cd ~/.dotfiles
bash install.sh
sync-secrets   # pull secrets from your encrypted store
```

Open a new terminal. Identical environment to your original machine.

---

## Syncing between machines

Two private git repos handle everything:

```
Machine A                            Machine B
─────────────────────────            ─────────────────────────
~/.dotfiles      ── git ──────────►  ~/.dotfiles
~/.password-store ── git ──────────► ~/.password-store
```

The daily cron runs at 09:00 on each machine:
1. `git pull` — picks up changes from all machines
2. Syncs this machine's iTerm2 profile
3. Runs a health check
4. Fixes what it can — pushes new commits, installs new packages

Change something on Machine A → commit and push → Machine B has it by morning.

### What syncs, what doesn't

| | Syncs | Stays local |
|---|---|---|
| zsh config (aliases, exports, tools) | ✓ | |
| git identity | ✓ | |
| Brewfile packages | ✓ | |
| Powerlevel10k prompt | ✓ | |
| iTerm2 profile (colors, fonts) | ✓ | |
| Secrets (tokens, API keys) | ✓ via pass store | |
| `~/.config/zsh/secrets.zsh` | | ✓ generated locally |
| `~/.config/zsh/local.zsh` | | ✓ machine-specific |
| iTerm2 key bindings | | ✓ machine-specific |

---

## Secrets

Two modes — pick one.

**Plain file** (no dependencies): skip pass setup during install. Edit `~/.config/zsh/secrets.zsh` directly. Gitignored — never committed. Fill it in manually on each machine.

**pass + GPG** (syncs across machines):

```bash
gpg --gen-key
pass init <your-gpg-key-id>
pass insert tokens/github-pat
pass insert tokens/openai-api-key

cd ~/.password-store
git remote add origin git@github.com:you/pass-store
git push -u origin main
```

Wire secrets into `sync-secrets` in `zsh/config/aliases.zsh`, then run `sync-secrets` to generate `~/.config/zsh/secrets.zsh`. Run it again whenever you rotate a key.

**Moving your GPG key to a new machine:**

```bash
# Original machine
gpg --export-secret-keys --armor > key.asc
# Transfer via AirDrop or USB — never email or cloud
# New machine
gpg --import key.asc && rm key.asc
```

---

## iTerm2

Each machine tracks its own profile in git. Colors, fonts, cursor, and scrollback are captured automatically by the daily cron. Key bindings stay local.

```bash
iterm2-log              # see your profile history with timestamps
iterm2-restore <hash>   # roll back to a previous version
```

---

## Health and healing

```bash
bash scripts/health.sh   # full check — writes .health-report.json
bash scripts/heal.sh     # fix what the report flagged
```

Health checks: symlinks, Brewfile drift, secrets freshness, pass store sync, iTerm2 profile, p10k config, zsh startup, `.zshrc` lint, git sync.

Heal runs three passes:
1. **Safe** — symlinks, git pull/push, brew bundle, pass sync
2. **Agent** — delegates complex fixes to Claude CLI (if installed)
3. **Manual** — prints what needs human attention + macOS notification

---

## Reverting a bad install

```bash
bash scripts/restore-backup.sh
```

Lists every pre-install backup by timestamp. Pick one, confirm, and your original files are restored exactly as they were.

---

## Staying up to date with upstream

When you fork this repo, you own your copy. To pull in bug fixes from the original:

```bash
git remote add upstream git@github.com:original/zsh-dotfiles
git fetch upstream
git merge upstream/main
```

Review what changed before merging — these are your shell config files.

---

## Repo structure

```
zsh/
  .zshrc                 # minimal loader
  .p10k.zsh              # Powerlevel10k config
  local.zsh.example      # template for ~/.config/zsh/local.zsh
  config/
    aliases.zsh          # aliases, functions, sync-secrets
    exports.zsh          # PATH, EDITOR, runtime vars
    fzf.zsh              # fzf bindings and previews
    keybindings.zsh      # zsh key bindings
    tools.zsh            # tool initializers (pyenv, nvm, bun)
    secrets.example.zsh  # template — copy to ~/.config/zsh/secrets.zsh

git/
  .gitconfig             # identity — syncs across machines

bat/
  config                 # bat theme and style

iterm2/
  profiles/
    <hostname>.json      # per-machine iTerm2 profile

Brewfile                 # core packages
Brewfile.optional        # extras — uncomment what fits your stack

install.sh               # bootstrap or migrate

scripts/
  migrate.sh             # parse ~/.zshrc and distribute into modules
  link.sh                # create symlinks
  verify.sh              # assert symlinks are correct
  health.sh              # full environment check
  heal.sh                # fix what health flagged
  daily.sh               # cron entry point: pull → iterm2 → health → heal
  sync-iterm2.sh         # capture iTerm2 profile changes
  restore-iterm2.sh      # write a repo profile version back to iTerm2
  restore-backup.sh      # revert to a pre-install backup
  lint-zshrc.sh          # enforce .zshrc stays minimal
  install-cron.sh        # register the daily launchd job
  install-hooks.sh       # install git pre-commit hook
```

---

## Key bindings

| Key | Action |
|---|---|
| `Ctrl-T` | Fuzzy file picker with bat preview |
| `Ctrl-R` | Fuzzy history search |
| `Alt-C` / `Ctrl-F` | Fuzzy directory jump with tree preview |
| `Ctrl-X Ctrl-E` | Edit current command in `$EDITOR` |
| `Option+←` / `Option+→` | Word navigation |
| `Option+Backspace` | Delete word backwards |
| `Ctrl-Z` | Toggle suspend / foreground |

## Aliases

| Alias | Action |
|---|---|
| `fe` | Open any file in `$EDITOR` via fzf |
| `fkill` | Kill any process via fuzzy search |
| `frecent` | Open any recent file via fzf |
| `gs` | `git status` |
| `gst` | `git status --short` |
| `gbr` | Fuzzy branch switcher |
| `glog` | Git log with fzf + diff preview |
| `gfa` | Interactively stage files via fzf |
| `iterm2-log` | iTerm2 profile history with timestamps |
| `iterm2-restore <hash>` | Restore a previous iTerm2 profile |
| `sync-secrets` | Regenerate secrets.zsh from pass store |

---

## Make it yours

The zsh config, aliases, and Brewfile in this repo reflect my own setup and opinions. They work well for me — but your workflow is different.

When you fork this repo, treat the config files as a starting point, not a contract:

- Swap out packages in `Brewfile` for what you actually use
- Rewrite `aliases.zsh` to match your own shortcuts
- Add or remove tool inits in `tools.zsh`
- Adjust `exports.zsh` for your paths and editor

The tooling (install, health, heal, sync) is the reusable part. The config is just a default. Change anything you want in your fork — that's the whole point.

---

## Disclaimer

This project is provided as-is, built from personal daily use. It works on my machines but may have gaps or edge cases on yours. It makes changes to your shell environment — always review what it does before running it.

Your existing config is backed up before anything is modified. If something goes wrong, `bash scripts/restore-backup.sh` puts everything back.

Use it, break it, fix it, make it better. PRs welcome.

---

## License

MIT © [Mahmoud Nassar](https://github.com/NassarX)
