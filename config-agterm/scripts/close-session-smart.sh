#!/bin/sh
# ⌘Ц (agterm keymap, русский дубль ⌘W): повторяет приоритет встроенного
# closeActiveSession — сначала закрыть «покрытие» (zoom → dashboard → quick
# terminal → overlay → scratch активной сессии), и только если ничего нет —
# закрыть саму сессию (таб).
A=/opt/homebrew/bin/agtermctl

STATE=$("$A" tree --json --socket "$AGT_SOCKET" | /usr/bin/python3 -c "
import json,sys
t=json.load(sys.stdin)['result']['tree']
def out(s):
    print(s); raise SystemExit
if t.get('zoomedSurface'): out('zoom')
if t.get('dashboardMembers'): out('dashboard')
if t.get('quickVisible'): out('quick')
act=None
for ws in t['workspaces']:
    for s in ws['sessions']:
        if s.get('active'): act=s
if act and act.get('overlay'): out('overlay')
if act and act.get('scratch'): out('scratch')
out('close')
")

case "$STATE" in
  zoom)      "$A" surface zoom hide --socket "$AGT_SOCKET" ;;
  dashboard) "$A" dashboard --close --socket "$AGT_SOCKET" ;;
  quick)     "$A" quick hide --socket "$AGT_SOCKET" ;;
  overlay)   "$A" session overlay close --socket "$AGT_SOCKET" ;;
  scratch)   "$A" session scratch off --socket "$AGT_SOCKET" ;;
  *)         "$A" session close --socket "$AGT_SOCKET" ;;
esac
