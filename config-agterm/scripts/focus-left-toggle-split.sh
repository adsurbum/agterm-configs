#!/bin/sh
# ⌘\ (agterm keymap custom command): сначала фокус на левую панель, потом
# toggle сплита. Порядок важен: закрывать сплит, стоя в правой панели, —
# значит терять фокус вместе с ней. Env от keymap-раннера: $AGT_SESSION_ID.
AGTERMCTL=/opt/homebrew/bin/agtermctl

"$AGTERMCTL" session focus left --target "$AGT_SESSION_ID" --socket "$AGT_SOCKET"
"$AGTERMCTL" session split toggle --target "$AGT_SESSION_ID" --socket "$AGT_SOCKET"
