#!/bin/bash
# SessionEnd hook: forget the tab/pane -> conversation mapping when the user
# deliberately quits claude in that pane, so the .zshrc auto-launch doesn't
# resurrect it after the next restart. Counterpart of agterm-tab-map.sh.
#
# Careful about WHEN we delete — Claude Code runs SessionEnd hooks even when
# the terminal is being torn down (app quit/restart), and deleting there would
# destroy exactly the mapping the restart needs. So we delete ONLY on reasons
# that mean the USER deliberately quit claude at the prompt:
#   prompt_input_exit — Ctrl+C/Ctrl+D/exit at the prompt
#   logout            — /logout
#   exit              — explicit exit (if reported)
# Everything else (clear, other, unknown/empty, terminal death) keeps the map.
# The entry is also removed only if it still points to THIS session_id, so an
# end event from an old conversation can't wipe a newer mapping.
set -u
[ -n "${AGTERM_SESSION_ID:-}" ] || exit 0
input=$(cat)
read -r sid reason <<EOF
$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("session_id",""), d.get("reason",""))' <<<"$input" 2>/dev/null)
EOF
[ -n "${sid:-}" ] || exit 0
case "${reason:-}" in
  prompt_input_exit|logout|exit) ;;
  *) exit 0 ;;
esac
map="$HOME/.claude/agterm-tab-map/$AGTERM_SESSION_ID.${AGTERM_PANE:-left}"
if [ -f "$map" ] && [ "$(cat "$map")" = "$sid" ]; then
  rm -f "$map"
fi
exit 0
