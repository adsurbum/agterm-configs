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

# --- 0. защита локальных правок ------------------------------------------------
# install.sh перезаписывает keymap, скрипты и ghostty config. Если живой файл
# правили на этом компе и не перенесли в репо — правка молча пропала бы.
# Поэтому храним манифест хешей того, что ставили в прошлый раз. Живой файл
# перезаписываем, только если он совпадает с репо или не менялся с прошлой
# установки; иначе — стоп со списком (или --force: бэкап в .bak и перезапись).
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1
MANIFEST="$HOME/.config/agterm/.installed.sha256"

# «файл в репо|куда ставится|подставлять ли префикс brew»
GUARDED=("$HERE/config-agterm/keymap.conf|$HOME/.config/agterm/keymap.conf|1")
for f in "$HERE/config-agterm/scripts/"*.sh "$HERE/config-agterm/scripts/"*.py; do
  GUARDED+=("$f|$HOME/.config/agterm/scripts/$(basename "$f")|1")
done
GUARDED+=("$HERE/config-ghostty/config|$HOME/.config/ghostty/config|0")

sha() { shasum -a 256 | cut -d' ' -f1; }
expected_sha() {  # хеш файла из репо в том виде, в каком он встанет на этот комп
  if [ "$2" = 1 ] && [ "$PREFIX" != "/opt/homebrew" ]; then
    sed "s#/opt/homebrew#$PREFIX#g" "$1" | sha
  else
    sha < "$1"
  fi
}
recorded_sha() { [ -f "$MANIFEST" ] && awk -F'  ' -v p="$1" '$2 == p { print $1 }' "$MANIFEST" || true; }

CONFLICTS=()
for g in "${GUARDED[@]}"; do
  IFS='|' read -r src dst sub <<<"$g"
  [ -f "$dst" ] || continue
  live="$(sha < "$dst")"
  [ "$live" = "$(expected_sha "$src" "$sub")" ] && continue
  [ "$live" = "$(recorded_sha "$dst")" ] && continue
  CONFLICTS+=("$src|$dst")
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
  echo
  echo "⚠️  Эти файлы изменены на этом компе и отличаются от репо:"
  for c in "${CONFLICTS[@]}"; do
    IFS='|' read -r src dst <<<"$c"
    echo "   $dst"
    echo "      diff \"$src\" \"$dst\""
  done
  if [ "$FORCE" = 0 ]; then
    echo
    echo "Нужные локальные правки сначала перенеси в репо (закоммить и запушь), потом запусти снова."
    echo "Перезаписать всё равно (с бэкапом каждого файла в .bak): bash install.sh --force"
    exit 1
  fi
  for c in "${CONFLICTS[@]}"; do
    IFS='|' read -r src dst <<<"$c"
    cp "$dst" "$dst.bak"
    echo "   бэкап: $dst.bak"
  done
fi

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

# запомнить, что поставили, — по этому манифесту следующий запуск отличит
# «обновление из репо» от «локальной правки» (см. шаг 0)
: > "$MANIFEST"
for g in "${GUARDED[@]}"; do
  IFS='|' read -r src dst sub <<<"$g"
  [ -f "$dst" ] && printf '%s  %s\n' "$(sha < "$dst")" "$dst" >> "$MANIFEST"
done

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
