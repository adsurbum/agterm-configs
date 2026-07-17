#!/bin/sh
# ⌘⇧R (agterm keymap): показать выделенный текст с правильным порядком RTL
# (иврит/арабский). agterm/ghostty пока не умеет BiDi — строка в терминале
# идёт в логическом порядке и выглядит «задом наперёд». fribidi переупорядочивает
# её в ВИЗУАЛЬНЫЙ порядок, и в оверлее (тоже ghostty, без BiDi) она читается верно.
# $AGT_SELECTION экспортирует keymap-раннер. Выделять в TUI — Shift+drag.
A=/opt/homebrew/bin/agtermctl
FRIBIDI=/opt/homebrew/bin/fribidi

# Источник текста: живое выделение ghostty ($AGT_SELECTION); если ничего не
# выделено — берём весь буфер текущей панели (аналог «выделить всё»). Внутри TUI
# (Claude Code) обычный drag выделения ghostty НЕ создаёт (уходит программе), так
# что без Shift+drag сработает именно этот fallback «показать всё».
TEXT="$AGT_SELECTION"
if [ -z "$TEXT" ]; then
  TEXT=$("$A" session text --all --pane "${AGT_PANE:-left}" \
    --target "$AGT_SESSION_ID" --socket "$AGT_SOCKET" 2>/dev/null)
fi

if [ -z "$TEXT" ]; then
  "$A" notify "Пусто — ни выделения, ни текста на экране." --title "RTL"
  exit 0
fi

# подмести temp-файлы, застрявшие от форс-закрытия оверлея (когда less не успел
# выполнить свой rm) — старше 60 минут, чтобы не задеть активный просмотр.
find /tmp -maxdepth 1 -name 'agterm-rtl.*' -type f -mmin +60 -delete 2>/dev/null

TMP=$(mktemp /tmp/agterm-rtl.XXXXXX) || exit 1
printf '%s\n' "$TEXT" | "$FRIBIDI" --nopad > "$TMP"

# less читает любой объём; -R не трогает байты, выход по q. Оверлей и temp-файл
# живут только пока открыт less; при выходе less temp удаляется, оверлей закрывается.
"$A" session overlay open \
  "/bin/zsh -lc 'LESS= /usr/bin/less -R \"$TMP\"; rm -f \"$TMP\"'" \
  --target "$AGT_SESSION_ID" --follow
