#!/bin/sh
# ⌘⇧O (agterm keymap): открыть текущее выделение через macOS `open`.
# Нужно потому, что agterm по клику НЕ открывает локальные пути к файлам
# (голый путь без схемы вообще не ссылка; file:// он только «показывает в
# Finder»). Выделяешь путь/URL → шорткат → open. html → браузер, pdf → просмотр
# и т.д. $AGT_SELECTION экспортирует keymap-раннер; кавычки обязательны.
A=/opt/homebrew/bin/agtermctl

SEL=$(printf '%s' "$AGT_SELECTION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ -z "$SEL" ]; then
  "$A" notify "Нечего открывать — сначала выдели путь или URL" --title "Open selection"
  exit 0
fi
/usr/bin/open "$SEL" 2>/dev/null ||
  "$A" notify "Не удалось открыть: $SEL" --title "Open selection"
