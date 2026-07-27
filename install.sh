#!/bin/bash
# Перенос настроек agterm на новый Mac. Запускать НА НОВОМ компе из папки agterm-setup:
#   bash install.sh
#
# Копирует keymap + скрипты + ghostty-конфиги + тему на место, подставляет
# правильный префикс Homebrew (arm64 /opt/homebrew ↔ Intel /usr/local),
# делает скрипты исполняемыми и перезагружает keymap, если agterm запущен.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# --- предусловия -------------------------------------------------------------
[ -d /Applications/agterm.app ] || echo "⚠️  agterm.app не найден в /Applications — сначала установи agterm."
if ! command -v agtermctl >/dev/null 2>&1; then
  echo "⚠️  agtermctl не на PATH. Установи через agterm: Help ▸ Install Command Line Tool…"
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "⚠️  Homebrew не найден. Поставь brew, затем: brew install fribidi"
fi

# префикс Homebrew этого компа (для замены захардкоженного /opt/homebrew в скриптах)
PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
echo "Homebrew prefix: $PREFIX"

# --- 1. ~/.config/agterm (keymap + scripts) ----------------------------------
mkdir -p "$HOME/.config/agterm/scripts"
cp "$HERE/config-agterm/keymap.conf" "$HOME/.config/agterm/keymap.conf"
cp "$HERE/config-agterm/scripts/"*.sh "$HOME/.config/agterm/scripts/"
cp "$HERE/config-agterm/scripts/"*.py "$HOME/.config/agterm/scripts/"
chmod +x "$HOME/.config/agterm/scripts/"*.sh "$HOME/.config/agterm/scripts/"*.py

# подставить локальный префикс homebrew вместо /opt/homebrew везде
if [ "$PREFIX" != "/opt/homebrew" ]; then
  echo "Заменяю /opt/homebrew → $PREFIX в keymap и скриптах…"
  for f in "$HOME/.config/agterm/keymap.conf" "$HOME/.config/agterm/scripts/"*.sh "$HOME/.config/agterm/scripts/"*.py; do
    sed -i '' "s#/opt/homebrew#$PREFIX#g" "$f"
  done
fi

# --- 2. глобальный ~/.config/ghostty/config ----------------------------------
# ВНИМАНИЕ: перезаписывает существующий config. Если на новом компе он уже есть
# и важен — забэкапится в config.bak.
mkdir -p "$HOME/.config/ghostty"
if [ -f "$HOME/.config/ghostty/config" ]; then
  cp "$HOME/.config/ghostty/config" "$HOME/.config/ghostty/config.bak"
  echo "Старый ~/.config/ghostty/config сохранён как config.bak"
fi
cp "$HERE/config-ghostty/config" "$HOME/.config/ghostty/config"

# --- 3. app-support (тема, мышь, inheritGlobalGhosttyConfig) ------------------
AS="$HOME/Library/Application Support/agterm"
mkdir -p "$AS"
cp "$HERE/app-support/ghostty-settings.conf" "$AS/" 2>/dev/null || true
cp "$HERE/app-support/settings.json" "$AS/" 2>/dev/null || true

# --- 4. зависимость: fribidi (для ⌘⇧H показ RTL) -----------------------------
if command -v brew >/dev/null 2>&1 && ! command -v fribidi >/dev/null 2>&1; then
  echo "Ставлю fribidi (нужен для показа иврита/RTL)…"
  brew install fribidi || echo "⚠️  не смог поставить fribidi — поставь вручную: brew install fribidi"
fi

# --- 5. применить keymap, если agterm уже запущен ----------------------------
if command -v agtermctl >/dev/null 2>&1; then
  agtermctl keymap reload >/dev/null 2>&1 && echo "keymap перезагружен." || \
    echo "keymap скопирован; применится при следующем запуске agterm (или File ▸ Reload Keymap)."
fi

# --- 6. launchd-агент авто-подгонки ширины сайдбара --------------------------
# Опрашивает дерево и держит sidebarWidth подогнанным под самый длинный ярлык.
# Нужен, потому что inline-переименование (даблклик) не проходит через хуки.
LA="$HOME/Library/LaunchAgents"
LABEL="com.iliakohanovski.agterm-fit-sidebar"
mkdir -p "$LA"
sed "s#__HOME__#$HOME#g" "$HERE/config-agterm/launchd/$LABEL.plist" > "$LA/$LABEL.plist"
GUI="gui/$(id -u)"
launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
if launchctl bootstrap "$GUI" "$LA/$LABEL.plist" 2>/dev/null; then
  echo "✓ launchd-агент авто-ширины сайдбара загружен ($LABEL)"
else
  launchctl load -w "$LA/$LABEL.plist" 2>/dev/null \
    && echo "✓ launchd-агент авто-ширины сайдбара загружен (load -w)" \
    || echo "⚠️  не смог загрузить launchd-агент — вручную: launchctl bootstrap $GUI $LA/$LABEL.plist"
fi

echo
echo "✅ Готово. Осталось вручную (если нужно):"
echo "  • тема/шрифт/прозрачность задаются в Settings agterm — settings.json уже скопирован,"
echo "    но при первом запуске проверь Appearance."
echo "  • ⌘B (форк Claude) + авто-резюме табов — поставь отдельным установщиком:"
echo "        bash claude-tab-resume/install.sh"
echo "    (после того как Claude Code настроен на этом компе; см. README)."
