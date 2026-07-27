#!/bin/sh
# ⌘⇧] / ⌘⇧[ (agterm keymap custom command): next/prev по сессиям только
# ОТКРЫТЫХ секций сайдбара — сессии свёрнутых воркспейсов пропускаются
# (встроенные next/previous_session обходят все подряд).
#
# Socket-дерево не отдаёт expanded/collapsed, поэтому набор свёрнутых читается
# из persisted-состояния окна (~/Library/Application Support/agterm/windows/
# <window-id>.json) — agterm перезаписывает его в течение секунд после любого
# изменения сайдбара. В flagged-режиме сайдбара секций нет — fallback на
# обычный next/prev по всем сессиям.
#
# Аргумент: next | prev (по умолчанию next). Обход — в порядке сайдбара с
# заворотом (last→first). Старт — от активной сессии, даже если её собственный
# воркспейс свёрнут. Нет подходящих сессий — тихий no-op. Env от
# keymap-раннера: $AGT_WINDOW_ID, $AGT_SOCKET.
AGTERMCTL=/opt/homebrew/bin/agtermctl
DIR="${1:-next}"
STATE="$HOME/Library/Application Support/agterm/windows/$AGT_WINDOW_ID.json"

TARGET=$("$AGTERMCTL" tree --json --window "$AGT_WINDOW_ID" --socket "$AGT_SOCKET" | /usr/bin/python3 -c "
import json,sys
direction='$DIR'
t=json.load(sys.stdin)['result']['tree']
collapsed=set()
if t.get('sidebarMode')!='flagged':
    try:
        for w in json.load(open('$STATE'))['workspaces']:
            if w.get('collapsed'): collapsed.add(w['id'].upper())
    except Exception:
        pass  # state-файла ещё нет — считаем все воркспейсы открытыми
ids=[]; ok=[]; act=-1
for ws in t['workspaces']:
    open_ws=ws['id'].upper() not in collapsed
    for s in ws['sessions']:
        if s.get('active'): act=len(ids)
        ids.append(s['id'])
        ok.append(open_ws)
n=len(ids)
if n==0 or not any(ok):
    raise SystemExit
if act<0: act=0
step=1 if direction=='next' else -1
i=act
for _ in range(n):
    i=(i+step)%n
    if ok[i]:
        print(ids[i]); break
")

[ -n "$TARGET" ] && "$AGTERMCTL" session select --target "$TARGET" --socket "$AGT_SOCKET"
