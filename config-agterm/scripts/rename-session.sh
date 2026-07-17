#!/bin/sh
# ⌘К (agterm keymap, русский дубль ⌘R): переименовать сессию. Встроенный
# инлайн-редактор через сокет не открыть (`session rename` требует имя
# аргументом), поэтому спрашиваем имя диалогом osascript и применяем.
# Env от keymap-раннера: $AGT_SESSION_ID, $AGT_SESSION_NAME.
A=/opt/homebrew/bin/agtermctl

NEW=$(/usr/bin/osascript -e "try
set r to display dialog \"Новое имя сессии:\" default answer \"$AGT_SESSION_NAME\" with title \"Rename Session\"
text returned of r
end try") || exit 0

[ -n "$NEW" ] && "$A" session rename "$NEW" --target "$AGT_SESSION_ID" --socket "$AGT_SOCKET"
