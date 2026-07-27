#!/bin/sh
# Claude Code status line — avit-zsh-inspired:
#   <last-3-path-components>  <git-branch>  <model> | ctx:<percent>% | <session-id>

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd')

# Last 3 path components, like avit's %3~
short_dir=$(echo "$cwd" | awk -F'/' '{
  n=NF;
  if (n<=3) print $0;
  else print "..."$(n-2)"/"$(n-1)"/"$n
}')

# Git branch (suppressed on non-repo dirs)
git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)

# Model display name
model=$(echo "$input" | jq -r '.model.display_name')

# Effort level — not in stdin, read from settings (local > project > user)
effort=""
for f in "$cwd/.claude/settings.local.json" "$cwd/.claude/settings.json" "$HOME/.claude/settings.json"; do
  [ -f "$f" ] || continue
  e=$(jq -r '.effortLevel // empty' "$f" 2>/dev/null)
  if [ -n "$e" ]; then effort=" eff:$e"; break; fi
done

# Context usage percentage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx=""
[ -n "$used" ] && ctx=" | ctx:$(printf '%.0f' "$used")%"

# Rate limits (only present for Claude.ai subscribers after first API response)
rl5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl7=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl=""
if [ -n "$rl5" ] || [ -n "$rl7" ]; then
  a=$([ -n "$rl5" ] && printf '%.0f' "$rl5" || echo "-")
  b=$([ -n "$rl7" ] && printf '%.0f' "$rl7" || echo "-")
  rl=" | 5h:${a}% 7d:${b}%"
fi

# Session id — short form matches the 8-char id /fork and the session list show
full_sid=$(echo "$input" | jq -r '.session_id // empty')
sid=$(printf '%s' "$full_sid" | cut -c1-8)
[ -n "$sid" ] && sid=" | $sid"

# Per-pane map that ⌘B (fork-claude.sh) and the .zshrc auto-resume read. Written
# here rather than only from the SessionStart hook: the status line renders on
# every frame and ONLY for an interactive TUI session, so the map always holds
# the id shown on screen — after /clear, --resume, --fork-session, compaction —
# and headless `claude -p` runs can never claim the pane.
if [ -n "${AGTERM_SESSION_ID:-}" ] && [ -n "$full_sid" ]; then
  map="$HOME/.claude/agterm-tab-map/$AGTERM_SESSION_ID.${AGTERM_PANE:-left}"
  if [ "$(cat "$map" 2>/dev/null)" != "$full_sid" ] || [ ! -f "$map.transcript" ]; then
    mkdir -p "$HOME/.claude/agterm-tab-map"
    printf '%s' "$full_sid" > "$map.$$" && mv -f "$map.$$" "$map"
    # Transcript path as Claude itself reports it, so ⌘B can confirm the session
    # is really there instead of deriving the ~/.claude/projects slug from the
    # cwd — the .zshrc wrapper (tr '/' '-') and crs() (sed on non-alnum) already
    # disagree on that encoding, and neither survives a dot or space in a path.
    tp=$(echo "$input" | jq -r '.transcript_path // empty')
    if [ -n "$tp" ]; then
      printf '%s' "$tp" > "$map.transcript.$$" && mv -f "$map.transcript.$$" "$map.transcript"
    fi
  fi
fi

if [ -n "$git_branch" ]; then
  printf "\033[34m%s\033[0m \033[32m%s\033[0m \033[90m%s%s%s%s%s\033[0m" \
    "$short_dir" "$git_branch" "$model" "$effort" "$ctx" "$rl" "$sid"
else
  printf "\033[34m%s\033[0m \033[90m%s%s%s%s%s\033[0m" \
    "$short_dir" "$model" "$effort" "$ctx" "$rl" "$sid"
fi
