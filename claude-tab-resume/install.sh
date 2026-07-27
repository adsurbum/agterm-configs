#!/bin/bash
# Перенос системы «каждый таб/панель agterm помнит свою Claude-сессию + авто-резюме»
# и зависимости для ⌘B (форк Claude). Запускать НА НОВОМ компе:
#   bash claude-tab-resume/install.sh
#
# Ставит: 2 хука в ~/.claude/hooks, статуслайн, записи в ~/.claude/settings.json,
# обёртку claude() и автозапуск в ~/.zshrc. Всё идемпотентно — повторный запуск
# ничего не дублирует. Пути берутся из $HOME текущего пользователя.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# --- 1. хуки -----------------------------------------------------------------
mkdir -p "$HOME/.claude/hooks"
cp "$HERE/hooks/agterm-tab-map.sh" "$HERE/hooks/agterm-tab-unmap.sh" "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/agterm-tab-map.sh" "$HOME/.claude/hooks/agterm-tab-unmap.sh"
echo "✓ хуки скопированы в ~/.claude/hooks"

# --- 1b. статуслайн ----------------------------------------------------------
# Не только рисует строку: он же пишет per-pane map (session_id + путь к
# транскрипту) на каждом кадре — то есть это ОСНОВНОЙ источник id для ⌘B и
# авто-резюме, а SessionStart-хук лишь закрывает первые кадры. Без него карта
# отстаёт от /clear, --resume, --fork-session. Чужой статуслайн не затираем
# молча — бэкап в .bak.
SL="$HOME/.claude/statusline-command.sh"
if [ -f "$SL" ] && ! cmp -s "$SL" "$HERE/statusline-command.sh"; then
  cp "$SL" "$SL.bak"
  echo "  прежний statusline-command.sh сохранён как statusline-command.sh.bak"
fi
cp "$HERE/statusline-command.sh" "$SL"
chmod +x "$SL"
command -v jq >/dev/null 2>&1 || echo "⚠️  jq не найден — статуслайну он нужен: brew install jq"
echo "✓ statusline-command.sh скопирован в ~/.claude"

# --- 2. settings.json: вмержить hook-записи + statusLine (идемпотентно) ------
python3 - "$HOME" <<'PY'
import json, os, sys
home = sys.argv[1]
path = os.path.join(home, ".claude", "settings.json")
try:
    with open(path) as f: s = json.load(f)
except FileNotFoundError:
    s = {}
except json.JSONDecodeError:
    print("⚠️  ~/.claude/settings.json не парсится — пропускаю мерж хуков, добавь вручную."); sys.exit(0)

hooks = s.setdefault("hooks", {})

def ensure(event, script):
    cmd = f"bash '{home}/.claude/hooks/{script}'"
    entries = hooks.setdefault(event, [])
    # уже есть?
    if any(script in json.dumps(e) for e in entries):
        return False
    # найти matcher "*" и дописать туда, иначе создать
    for e in entries:
        if e.get("matcher") == "*":
            e.setdefault("hooks", []).append({"type": "command", "command": cmd, "timeout": 10})
            return True
    entries.append({"matcher": "*", "hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
    return True

a = ensure("SessionStart", "agterm-tab-map.sh")
b = ensure("SessionEnd", "agterm-tab-unmap.sh")

# statusLine ставим только если его нет: свой кастомный статуслайн у человека
# важнее нашего, а pane-map тогда останется на одном SessionStart-хуке.
c = False
if not s.get("statusLine"):
    s["statusLine"] = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}
    c = True
elif "statusline-command.sh" not in json.dumps(s["statusLine"]):
    print("⚠️  в settings.json уже есть свой statusLine — оставляю его. Чтобы ⌘B")
    print("    получал id как в статуслайне, перенеси в него блок записи pane-map")
    print("    из ~/.claude/statusline-command.sh.")

if a or b or c:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        import shutil; shutil.copy(path, path + ".bak")
    with open(path, "w") as f: json.dump(s, f, indent=2, ensure_ascii=False)
    print("✓ записи добавлены в ~/.claude/settings.json (бэкап .bak)")
else:
    print("✓ записи уже были на месте — пропущено")
PY

# --- 3. ~/.zshrc: обёртка claude() + автозапуск (идемпотентно) ---------------
ZRC="$HOME/.zshrc"
touch "$ZRC"
if grep -q '__CLAUDE_TAB_RESUME_WRAPPER__' "$ZRC"; then
  echo "✓ claude() обёртка уже в ~/.zshrc — пропущено"
else
  {
    echo ""
    echo "# >>> __CLAUDE_TAB_RESUME_WRAPPER__ >>>"
    cat "$HERE/zshrc-claude-wrapper.sh"
    echo "# <<< __CLAUDE_TAB_RESUME_WRAPPER__ <<<"
  } >> "$ZRC"
  echo "✓ claude() обёртка добавлена в ~/.zshrc (функция видна независимо от позиции)"
fi

if grep -q 'claude tab auto-resume' "$ZRC"; then
  echo "✓ автозапуск уже в ~/.zshrc — пропущено"
else
  { echo ""; cat "$HERE/zshrc-autostart.sh"; } >> "$ZRC"
  echo "✓ автозапуск добавлен в конец ~/.zshrc"
fi

echo
echo "✅ Готово. Открой НОВЫЙ таб/сессию (или source ~/.zshrc), чтобы применилось."
echo "   Проверка: в agterm-сессии с запущенным claude появятся файлы"
echo "   ~/.claude/agterm-tab-map/<session-id>.<pane> и .<pane>.transcript,"
echo "   а id в них совпадёт с коротким id в статуслайне."
