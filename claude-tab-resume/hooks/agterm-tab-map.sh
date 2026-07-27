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
# Only wrapper-launched interactive sessions may claim the pane map (the zshrc
# claude() wrapper sets this). Headless `claude -p` runs from eval scripts /
# subprocesses inherit AGTERM_* env and used to clobber the map, so ⌘B forked
# and bare-`claude` resumed a random eval session instead of the pane's own.
[ -n "${AGTERM_CLAUDE_INTERACTIVE:-}" ] || exit 0
sid=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)
if [ -n "$sid" ]; then
  mkdir -p "$HOME/.claude/agterm-tab-map"
  printf '%s' "$sid" > "$HOME/.claude/agterm-tab-map/$AGTERM_SESSION_ID.${AGTERM_PANE:-left}"
fi

# Подогнать ширину сайдбара под самый длинный ярлык: старт приложения, новый таб
# и ⌘B-форк — все стартуют claude, значит все проходят через этот хук. Мягкая
# зависимость от config-agterm: если fit-sidebar не установлен — тихо пропускаем.
FIT="$HOME/.config/agterm/scripts/fit-sidebar.py"
[ -x "$FIT" ] && "$FIT" >/dev/null 2>&1
exit 0
