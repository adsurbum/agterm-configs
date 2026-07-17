#!/bin/bash
# SessionStart hook: record which Claude conversation lives in which agterm
# tab AND pane. Writes ~/.claude/agterm-tab-map/<AGTERM_SESSION_ID>.<pane>
# (pane = left|right|scratch, from AGTERM_PANE; defaults to left) with the
# claude session_id, so the `claude` shell wrapper / the .zshrc auto-launch
# block can resume this exact conversation in this exact pane after a restart.
# Latest start wins (new chat, /clear, resume all update the mapping).
# Silent no-op outside agterm; never blocks the agent.
set -u
[ -n "${AGTERM_SESSION_ID:-}" ] || exit 0
sid=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)
if [ -n "$sid" ]; then
  mkdir -p "$HOME/.claude/agterm-tab-map"
  printf '%s' "$sid" > "$HOME/.claude/agterm-tab-map/$AGTERM_SESSION_ID.${AGTERM_PANE:-left}"
fi
exit 0
