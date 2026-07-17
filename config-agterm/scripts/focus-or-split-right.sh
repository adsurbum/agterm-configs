#!/bin/sh
# ⌘] (agterm keymap custom command): фокус на правую панель; если сплита нет
# (или он скрыт) — сначала открыть его. Env от keymap-раннера: $AGT_SESSION_ID.
AGTERMCTL=/opt/homebrew/bin/agtermctl

SHOWN=$("$AGTERMCTL" tree --json --socket "$AGT_SOCKET" | /usr/bin/python3 -c "
import json,sys
t=json.load(sys.stdin)['result']['tree']
sid='$AGT_SESSION_ID'.upper()
for ws in t['workspaces']:
    for s in ws['sessions']:
        if s['id'].upper()==sid:
            print(1 if s.get('split') else 0)
")

if [ "$SHOWN" != "1" ]; then
  "$AGTERMCTL" session split on --target "$AGT_SESSION_ID" --socket "$AGT_SOCKET"
fi
"$AGTERMCTL" session focus right --target "$AGT_SESSION_ID" --socket "$AGT_SOCKET"
