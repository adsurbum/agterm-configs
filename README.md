# agterm-configs

My **agterm** terminal setup: custom keyboard shortcuts, the scripts they call,
ghostty config, theme, plus a separate "each tab/pane remembers its own Claude
session + auto-resume" system (needed for ⌘B — fork Claude).

Everything is portable: scripts use `$HOME` and `$AGT_*`, and the installer
rewrites the Homebrew prefix automatically (arm64 `/opt/homebrew` ↔ Intel
`/usr/local`).

## Install on a new Mac

```sh
# 1. Install agterm.app into /Applications, then in agterm:
#    Help ▸ Install Command Line Tool…   (puts agtermctl on PATH)

# 2. Clone this repo
git clone git@github.com:adsurbum/agterm-configs.git
cd agterm-configs

# 3. Core agterm setup (keymap, scripts, ghostty, theme, fribidi)
bash install.sh

# 4. (optional) ⌘B "fork Claude" + tab auto-resume.
#    Run this AFTER Claude Code is set up (logged in) on this machine:
bash claude-tab-resume/install.sh

# 5. (optional) Faster zsh startup — trims oh-my-zsh plugins, inlines brew shellenv
bash shell-speedup/install.sh

# 6. Restart agterm so the menu shortcuts are picked up
```

## What's in the repo

| Path | What | Installs to |
|------|------|-------------|
| `config-agterm/keymap.conf` | all shortcuts (see below) | `~/.config/agterm/keymap.conf` |
| `config-agterm/scripts/` | scripts behind the shortcuts | `~/.config/agterm/scripts/` |
| `config-ghostty/config` | global ghostty config | `~/.config/ghostty/config` |
| `app-support/` | theme, scroll, right-click | `~/Library/Application Support/agterm/` |
| `claude-tab-resume/` | hooks + status line + zshrc for ⌘B & auto-resume | `~/.claude/`, `~/.zshrc` |
| `shell-speedup/` | in-place edits that speed up zsh startup (see below) | `~/.zshrc`, `~/.zprofile` |

## Shortcuts

| Keys | Action |
|------|--------|
| ⌘N | new session in the current directory |
| ⌘⌥⇧N | new session in `$HOME` |
| ⌘B | new tab with a fork of this pane's Claude session |
| ⌘D | new tab in the same directory running a fresh `claude` |
| ⌘] | focus the right pane (opens the split if there isn't one) |
| ⌘\ | focus the left pane and toggle the split |
| ⌘R | rename the session |
| ⌘⇧O | open the selected path/URL with `open` |
| ⌘⇧H | show the selection (or the whole screen) with correct RTL order (Hebrew) |
| ⌘T | toggle theme (Solarized Dark ↔ Light) |
| ⌃⇧] / ⌃⇧[ | next / previous session with an agent status |
| ⌥⇧] / ⌥⇧[ | next / previous flagged session |
| ⌥F | toggle the flag on the current session |

Since agterm 0.38 a Latin chord also fires under the Russian layout, so the
keymap no longer carries Cyrillic `(ru)` duplicates.

## Dependencies

- **agterm.app** + `agtermctl` (installed from agterm's menu)
- **Homebrew** and **fribidi** (`brew install fribidi`) — for ⌘⇧H (Hebrew/RTL);
  installed automatically by `install.sh`

## Notes

- `install.sh` overwrites an existing `~/.config/ghostty/config` (the old one is
  backed up as `config.bak`).
- `claude-tab-resume/install.sh` is idempotent: it merges hook entries into
  `~/.claude/settings.json` WITHOUT touching your other hooks (backup `.bak`), and
  appends the `~/.zshrc` blocks by marker so re-running never duplicates them.
- The status line is load-bearing, not decoration: it writes
  `~/.claude/agterm-tab-map/<tab>.<pane>` (+ `.transcript`) on every frame, which
  is where ⌘B and the auto-resume read the conversation id from. It runs only for
  an interactive TUI session, so the map always matches the id shown on screen and
  headless `claude -p` runs can't claim a pane. The `SessionStart` hook writes the
  same file, covering the frames before the first render. If you already have your
  own `statusLine` in `settings.json` the installer keeps it and tells you to port
  the map-writing block over.
- agterm's "Restore running commands on restart" setting must stay OFF — the tab
  auto-resume system replaces it and must not depend on it.

## Faster zsh startup (`shell-speedup/`)

Every agterm tab — and ⌘D, which runs `zsh -lic 'claude; …'` — pays for the full
`~/.zprofile` + `~/.zshrc` load. `shell-speedup/install.sh` edits both files in
place (backups `.bak`, idempotent):

| Change | Why | Saves |
|--------|-----|-------|
| drop `autojump` from `plugins=()` | its init forks `brew --prefix` twice, plus a python process on every `cd` | ~35 ms |
| drop `poetry` from `plugins=()` | runs `poetry completions zsh` (python) in the background on every shell start; completion stays cached | ~270 ms CPU |
| drop `git` from `plugins=()` | ~200 aliases; the prompt's branch/status comes from oh-my-zsh core, not the plugin | ~6 ms |
| comment out `zsh-abbr` | no abbreviations configured | ~10 ms |
| `~/.zprofile`: replace `eval "$(brew shellenv)"` with its output | no brew fork per login shell; generated on the target machine, so the prefix is right | ~15 ms |

Measured on the origin machine: time to prompt 118 → 58 ms, login shell (⌘D)
~115 → ~45 ms. Bare zsh is ~11 ms; oh-my-zsh itself costs ~40 ms. If Homebrew
ever moves, re-run `brew shellenv` and re-paste its output into `~/.zprofile`
(the original `eval` line is kept there, commented out).

## Updating configs FROM the live machine

The repo files are snapshots; the live files (`~/.config/agterm/...`,
`~/.claude/hooks/...`, `~/.zshrc`) are the source of truth. To sync back, copy the
changed files into this clone and push. (Done manually for now.)

## Pushing to this repo

Push over **HTTPS with a `gh` token** (`gh auth login`), not SSH: the SSH key on
the origin machine is a deploy key scoped to another repo, so `git push` over SSH
is denied here.
```sh
git remote set-url origin https://github.com/adsurbum/agterm-configs.git
```
