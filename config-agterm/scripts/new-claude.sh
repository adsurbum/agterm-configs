#!/bin/sh
# ⌘D (agterm keymap custom command): новый таб в той же директории со СВЕЖИМ
# claude. Не форк — форк текущей беседы это ⌘B (fork-claude.sh).
#
# Процесс сессии задаётся через --command, а не «создать шелл и напечатать в
# него команду» (как в ⌘B): так нет гонки «успел ли зшелл подняться» и не нужен
# sleep. Разбор строки:
#   zsh -l  — нужен .zprofile/.zshrc, иначе не будет ни claude в PATH
#             (~/.local/bin), ни обёртки claude() (она даёт --name и
#             AGTERM_CLAUDE_INTERACTIVE=1 для pane-map).
#   -i      — блок авто-резюме из .zshrc срабатывает только в интерактивном
#             шелле; у нового таба своего pane-map нет, поэтому он отработает
#             вхолостую, но выставит _CLAUDE_TAB_AUTOSTARTED=1. Это экспорт —
#             он и защищает `exec zsh` ниже от повторного автозапуска claude.
#   exec zsh -l — без него таб закрылся бы при выходе из claude (--command:
#             «the session closes when it exits»); так он падает в обычный шелл.
# Env от keymap-раннера: $AGT_SESSION_PWD, $AGT_SESSION_ID, $AGT_SOCKET.
AGTERMCTL=/opt/homebrew/bin/agtermctl

exec "$AGTERMCTL" session new \
  --cwd "$AGT_SESSION_PWD" \
  --after "$AGT_SESSION_ID" \
  --socket "$AGT_SOCKET" \
  --command "zsh -lic 'claude; exec zsh -l'"
