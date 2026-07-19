#!/bin/sh
# ⌃] / ⌃[ (agterm keymap custom command): переход между сессиями со СТАТУСОМ
# агента — active (серый глиф), completed (зелёный), blocked (красный). Шире
# встроенного next/previous_attention_session, который берёт только
# completed+blocked (зелёный+красный) и пропускает серый active.
#
# Аргумент: next | prev (по умолчанию next). Обход — по всем сессиям окна в
# порядке сайдбара, с заворотом (last→first). Старт — от активной сессии; если
# у неё самой статуса нет, всё равно прыгаем к ближайшей со статусом вперёд/назад.
# Если сессий со статусом нет вовсе — тихий no-op. Env от keymap-раннера:
# $AGT_WINDOW_ID, $AGT_SOCKET.
AGTERMCTL=/opt/homebrew/bin/agtermctl
DIR="${1:-next}"

TARGET=$("$AGTERMCTL" tree --json --window "$AGT_WINDOW_ID" --socket "$AGT_SOCKET" | /usr/bin/python3 -c "
import json,sys
direction='$DIR'
t=json.load(sys.stdin)['result']['tree']
ids=[]; has_status=[]; act=-1
for ws in t['workspaces']:
    for s in ws['sessions']:
        if s.get('active'): act=len(ids)
        ids.append(s['id'])
        has_status.append(bool(s.get('status')))
n=len(ids)
if n==0 or not any(has_status):
    raise SystemExit
if act<0: act=0
step=1 if direction=='next' else -1
i=act
for _ in range(n):
    i=(i+step)%n
    if has_status[i]:
        print(ids[i]); break
")

[ -n "$TARGET" ] && "$AGTERMCTL" session select --target "$TARGET" --socket "$AGT_SOCKET"
