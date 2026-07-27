#!/bin/sh
# «Подгонка сайдбара». agterm НЕ даёт менять ширину сайдбара по сокету, поэтому
# вместо расширения/сжатия колонки укорачиваем слишком длинное ИМЯ сессии, чтобы
# строка помещалась. Дёргается из rename-session.sh после переименования.
#
# Серединный эллипсис (…) сохраняет и начало, и хвост имени — хвост часто
# различает форки ("fork: … 14:13"). ВНИМАНИЕ: усечение НЕОБРАТИМО — полное имя
# в agterm после этого не восстановить.
#
# Цель: $AGT_SESSION_ID (keymap-раннер) → иначе $AGTERM_SESSION_ID (обычный
# шелл) → иначе $1. Сокет: $AGT_SOCKET → $AGTERM_SOCKET (иначе автоподбор).
# Предел длины: $AGT_SIDEBAR_MAX (по умолчанию 28).
AGTERMCTL=/opt/homebrew/bin/agtermctl
TARGET="${AGT_SESSION_ID:-${AGTERM_SESSION_ID:-$1}}"
SOCKET="${AGT_SOCKET:-$AGTERM_SOCKET}"
MAX="${AGT_SIDEBAR_MAX:-28}"
[ -n "$TARGET" ] || exit 0

ctl() {
  if [ -n "$SOCKET" ]; then "$AGTERMCTL" "$@" --socket "$SOCKET"
  else "$AGTERMCTL" "$@"; fi
}

SHORT=$(ctl tree --json | /usr/bin/python3 -c "
import json,sys
target='$TARGET'.upper()
limit=$MAX
t=json.load(sys.stdin)['result']['tree']
name=None
for ws in t['workspaces']:
    for s in ws['sessions']:
        if s['id'].upper()==target:
            name=s.get('name','')
if name is None or len(name)<=limit:
    raise SystemExit           # нечего усекать
keep=limit-1                   # одну позицию отдаём под …
head=(keep+1)//2
tail=keep-head
sys.stdout.write(name[:head]+'…'+(name[len(name)-tail:] if tail else ''))
")

[ -n "$SHORT" ] && ctl session rename "$SHORT" --target "$TARGET"
