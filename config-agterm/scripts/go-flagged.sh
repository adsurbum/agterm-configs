#!/bin/sh
# ⌥⇧] / ⌥⇧[ (agterm keymap custom command): переход только между ФЛАЖКОВАННЫМИ
# сессиями (`session flag`, ⌘⇧F). Встроенные next/previous_session сужаются до
# флагов только в flagged-режиме сайдбара; этот скрипт ходит по флагам всегда,
# не переключая вид сайдбара.
#
# Аргумент: next | prev (по умолчанию next). Обход — по всем сессиям окна в
# порядке сайдбара, с заворотом (last→first). Старт — от активной сессии; если
# она сама не флажкована, всё равно прыгаем к ближайшей флажкованной вперёд/назад.
# Флагов нет вовсе — тихий no-op. Env от keymap-раннера: $AGT_WINDOW_ID, $AGT_SOCKET.
AGTERMCTL=/opt/homebrew/bin/agtermctl
DIR="${1:-next}"

TARGET=$("$AGTERMCTL" tree --json --window "$AGT_WINDOW_ID" --socket "$AGT_SOCKET" | /usr/bin/python3 -c "
import json,sys
direction='$DIR'
t=json.load(sys.stdin)['result']['tree']
ids=[]; flagged=[]; act=-1
for ws in t['workspaces']:
    for s in ws['sessions']:
        if s.get('active'): act=len(ids)
        ids.append(s['id'])
        flagged.append(bool(s.get('flagged')))
n=len(ids)
if n==0 or not any(flagged):
    raise SystemExit
if act<0: act=0
step=1 if direction=='next' else -1
i=act
for _ in range(n):
    i=(i+step)%n
    if flagged[i]:
        print(ids[i]); break
")

[ -n "$TARGET" ] && "$AGTERMCTL" session select --target "$TARGET" --socket "$AGT_SOCKET"
