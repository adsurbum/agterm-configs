#!/bin/sh
# Переключает тему agterm между двумя любимыми:
#   «Solarized Dark Higher Contrast»  ↔  «iTerm2 Solarized Light»
# Текущая тема определяется по строке, помеченной `*` в `theme list`.
set -eu

AGTERMCTL=/opt/homebrew/bin/agtermctl
DARK="Solarized Dark Higher Contrast"
LIGHT="iTerm2 Solarized Light"

# socket: из окружения (custom-command выставляет $AGT_SOCKET), иначе дефолт
SOCK="${AGT_SOCKET:-$HOME/Library/Application Support/agterm/agterm.sock}"

current=$("$AGTERMCTL" theme list --socket "$SOCK" | sed -n 's/^\* //p' | head -n1)

case "$current" in
  "$DARK") next="$LIGHT" ;;
  *)       next="$DARK"  ;;   # из светлой (или любой другой) — в тёмную
esac

exec "$AGTERMCTL" theme set "$next" --socket "$SOCK"
