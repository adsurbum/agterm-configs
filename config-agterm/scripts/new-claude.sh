#!/bin/sh
# ⌘D (agterm keymap custom command): новый таб в той же директории со СВЕЖИМ
# claude. Не форк — форк текущей беседы это ⌘B (fork-claude.sh).
#
# Быстрый путь: если для этой директории есть прогретая запаска (claude уже
# запущен в фоновом воркспейсе «spares», см. claude-spare.py) — переносим её
# сразу под текущий таб и выбираем, без ~0.5 с старта claude. После — в фоне
# ставим новую запаску для этой директории.
#
# Обычный путь — процесс сессии задаётся через --command, а не «создать шелл и
# напечатать в него команду» (как в ⌘B): так нет гонки «успел ли зшелл
# подняться» и не нужен sleep. Разбор строки:
#   zsh -l  — нужен .zprofile/.zshrc, иначе не будет ни claude в PATH
#             (~/.local/bin), ни обёртки claude() (она даёт --name и
#             AGTERM_CLAUDE_INTERACTIVE=1 для pane-map).
#   -i      — блок авто-резюме из .zshrc срабатывает только в интерактивном
#             шелле; у нового таба своего pane-map нет, поэтому он отработает
#             вхолостую, но выставит _CLAUDE_TAB_AUTOSTARTED=1. Это экспорт —
#             он и защищает `exec zsh` ниже от повторного автозапуска claude.
#   exec zsh -l — без него таб закрылся бы при выходе из claude (--command:
#             «the session closes when it exits»); так он падает в обычный шелл.
# Env от keymap-раннера: $AGT_SESSION_PWD, $AGT_SESSION_ID, $AGT_WINDOW_ID, $AGT_SOCKET.
AGTERMCTL=/opt/homebrew/bin/agtermctl
SPARE="$HOME/.config/agterm/scripts/claude-spare.py"

open_spare() {
  sid=$("$SPARE" claim "$AGT_SESSION_PWD" 2>/dev/null) || return 1
  "$AGTERMCTL" session move --target "$sid" --after "$AGT_SESSION_ID" --socket "$AGT_SOCKET" >/dev/null &&
    "$AGTERMCTL" session select --target "$sid" --socket "$AGT_SOCKET" >/dev/null
}

open_spare || "$AGTERMCTL" session new \
  --cwd "$AGT_SESSION_PWD" \
  --after "$AGT_SESSION_ID" \
  --socket "$AGT_SOCKET" \
  --command "zsh -lic 'claude; exec zsh -l'"

# новая запаска — с паузой, чтобы её claude не стартовал одновременно с только
# что открытым и не тормозил его
(sleep 3; exec "$SPARE" refill "$AGT_SESSION_PWD") </dev/null >/dev/null 2>&1 &
