#!/bin/bash
# Перенос системы «каждый таб/панель agterm помнит свою Claude-сессию + авто-резюме»
# и зависимости для ⌘B (форк Claude). Запускать НА НОВОМ компе:
#   bash claude-tab-resume/install.sh
#
# Ставит: 2 хука в ~/.claude/hooks, hook-записи в ~/.claude/settings.json,
# обёртку claude() и автозапуск в ~/.zshrc. Всё идемпотентно — повторный запуск
# ничего не дублирует. Пути берутся из $HOME текущего пользователя.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# --- 1. хуки -----------------------------------------------------------------
mkdir -p "$HOME/.claude/hooks"
cp "$HERE/hooks/agterm-tab-map.sh" "$HERE/hooks/agterm-tab-unmap.sh" "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/agterm-tab-map.sh" "$HOME/.claude/hooks/agterm-tab-unmap.sh"
echo "✓ хуки скопированы в ~/.claude/hooks"

# --- 2. settings.json: вмержить hook-записи (идемпотентно) -------------------
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
if a or b:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        import shutil; shutil.copy(path, path + ".bak")
    with open(path, "w") as f: json.dump(s, f, indent=2, ensure_ascii=False)
    print("✓ hook-записи добавлены в ~/.claude/settings.json (бэкап .bak)")
else:
    print("✓ hook-записи уже были на месте — пропущено")
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
echo "   Проверка: в agterm-сессии с запущенным claude появится файл"
echo "   ~/.claude/agterm-tab-map/<session-id>.<pane>."
