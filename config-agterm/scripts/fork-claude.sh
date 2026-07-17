#!/bin/sh
# ⌘B (agterm keymap custom command): открыть новый таб в той же директории и
# запустить в нём ФОРК Claude-сессии той панели, где нажат шорткат.
# Claude session id берётся из per-pane map (~/.claude/agterm-tab-map/),
# который пишет SessionStart-хук agterm-tab-map.sh.
# Env от keymap-раннера: $AGT_SESSION_ID, $AGT_PANE, $AGT_SESSION_PWD.
AGTERMCTL=/opt/homebrew/bin/agtermctl

MAP="$HOME/.claude/agterm-tab-map/$AGT_SESSION_ID.${AGT_PANE:-left}"
if [ ! -s "$MAP" ]; then
  "$AGTERMCTL" notify "В этой панели нет Claude-сессии — форкать нечего" --title "Fork Claude"
  exit 0
fi
SID=$(cat "$MAP")

# Одно имя для таба и для самой Claude-сессии; время — чтобы различать форки.
LABEL="fork: $(basename "$AGT_SESSION_PWD") $(date +%H:%M)"

NEW=$("$AGTERMCTL" session new --cwd "$AGT_SESSION_PWD" --after "$AGT_SESSION_ID" \
  --name "$LABEL") || exit 1

# Дать новому шеллу подняться, затем впечатать команду. `session type` шлёт
# Return только за newline в тексте — поэтому \n в конце обязателен.
# `--name` перехватывает zshrc-обёртка claude() и подставляет вместо дефолтного
# basename $PWD — так форк сразу получает своё имя, без /rename внутри TUI.
sleep 1.2
printf 'claude --resume %s --fork-session --name "%s"\n' "$SID" "$LABEL" |
  "$AGTERMCTL" session type --stdin --target "$NEW"
