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

# 5. Restart agterm so the menu shortcuts are picked up
```

## What's in the repo

| Path | What | Installs to |
|------|------|-------------|
| `config-agterm/keymap.conf` | all shortcuts (see below) | `~/.config/agterm/keymap.conf` |
| `config-agterm/scripts/` | scripts behind the shortcuts | `~/.config/agterm/scripts/` |
| `config-ghostty/config` | global ghostty config | `~/.config/ghostty/config` |
| `app-support/` | theme, scroll, right-click | `~/Library/Application Support/agterm/` |
| `claude-tab-resume/` | hooks + status line + zshrc for ⌘B & auto-resume | `~/.claude/`, `~/.zshrc` |

## Shortcuts (English / Russian layout)

| Keys | Action |
|------|--------|
| ⌘N / ⌘Т | new session in the current directory |
| ⌘⌥⇧N | new session in `$HOME` |
| ⌘B / ⌘И | new tab with a fork of this pane's Claude session |
| ⌘D / ⌘В | new tab in the same directory running a fresh `claude` |
| ⌘] / ⌘Ъ | focus the right pane (opens the split if there isn't one) |
| ⌘R / ⌘К | rename the session |
| ⌘⇧O / ⌘⇧Щ | open the selected path/URL with `open` |
| ⌘⇧H / ⌘⇧Р | show the selection (or the whole screen) with correct RTL order (Hebrew) |
| ⌘T / ⌘Е | toggle theme (Solarized Dark ↔ Light) |
| ⌘Ц | close tab (Russian-layout twin of ⌘W, honoring overlay/quick/zoom) |

Plus Russian-layout twins for the built-ins: session navigation, split, scratch,
quick terminal, workspace, flag, search, dashboard.

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
