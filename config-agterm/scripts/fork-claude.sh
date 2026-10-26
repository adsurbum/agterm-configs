#!/bin/sh
# ⌘B (agterm keymap custom command): открыть новый таб в той же директории и
# запустить в нём ФОРК Claude-сессии той панели, где нажат шорткат.
# Claude session id берётся из per-pane map (~/.claude/agterm-tab-map/): его на
# каждом кадре пишет статуслайн (~/.claude/statusline-command.sh), поэтому в
# карте всегда ровно тот id, что виден на экране — после /clear, --resume,
# --fork-session и compaction. SessionStart-хук agterm-tab-map.sh закрывает
# первые кадры. Рядом лежит <map>.transcript с путём к транскрипту.
# Env от keymap-раннера: $AGT_SESSION_ID, $AGT_PANE, $AGT_SESSION_PWD.
AGTERMCTL=/opt/homebrew/bin/agtermctl

MAP="$HOME/.claude/agterm-tab-map/$AGT_SESSION_ID.${AGT_PANE:-left}"
if [ ! -s "$MAP" ]; then
  "$AGTERMCTL" notify "В этой панели нет Claude-сессии — форкать нечего" --title "Fork Claude"
  exit 0
fi
SID=$(cat "$MAP")

# Если транскрипт исчез (сессия удалена/переехала), `claude --resume` упал бы уже
# в новом табе — скажем сразу здесь. Карты без .transcript (написанные хуком)
# пропускаем: проверять нечего.
TRANSCRIPT="$MAP.transcript"
if [ -s "$TRANSCRIPT" ] && [ ! -f "$(cat "$TRANSCRIPT")" ]; then
  "$AGTERMCTL" notify "Транскрипт этой Claude-сессии не найден — форкать нечего" \
    --title "Fork Claude"
  exit 0
fi

# Имя Claude-сессии форка; время — чтобы различать форки. Таб получает его через
# заголовок терминала, который пишет Claude.
# База имени — имя ИСХОДНОЙ сессии ($AGT_SESSION_NAME), а не basename каталога:
# так форк наследует кастомное имя родителя (POC, morla, …). Срезаем индикатор
# статуса (✳/спиннер), ведущий "fork: " и хвостовой " ЧЧ:ММ", чтобы форк форка не
# копил префиксы и метки ("fork: fork: … 23:28 23:45"). Fallback на basename PWD.
BASE=$(AGT_SESSION_NAME="${AGT_SESSION_NAME:-$(basename "$AGT_SESSION_PWD")}" /usr/bin/python3 -c '
import os, re
s = os.environ["AGT_SESSION_NAME"]
g = r"^[\s⠀-⣿✳✨●○•]+"          # ведущий индикатор статуса (спиннер/✳/точки)
s = re.sub(g, "", s)              # он мог попасть в имя родителя
s = re.sub(r"^fork:\s*", "", s)  # прежний префикс "fork: "
s = re.sub(g, "", s)             # индикатор после префикса
s = re.sub(r"\s+\d{2}:\d{2}$", "", s)  # прежний хвост " ЧЧ:ММ"
print(s.strip())
')
LABEL="fork: $BASE $(date +%H:%M)"

# Без `--name`: имя, заданное в agterm, закрепляется и перестаёт следовать за
# заголовком терминала — тогда /rename внутри форка не меняет таб. Таб берёт
# имя из заголовка, а заголовок пишет Claude (--name ниже).
NEW=$("$AGTERMCTL" session new --cwd "$AGT_SESSION_PWD" --after "$AGT_SESSION_ID") || exit 1

# Дать новому шеллу подняться, затем впечатать команду. `session type` шлёт
# Return только за newline в тексте — поэтому \n в конце обязателен.
# `--name` перехватывает zshrc-обёртка claude() и подставляет вместо дефолтного
# basename $PWD — так форк сразу получает своё имя, без /rename внутри TUI.
sleep 1.2
printf 'claude --resume %s --fork-session --name "%s"\n' "$SID" "$LABEL" |
  "$AGTERMCTL" session type --stdin --target "$NEW"
