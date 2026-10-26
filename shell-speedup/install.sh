#!/bin/bash
# Ускорение старта zsh (oh-my-zsh) — те же правки, что сделаны на основном компе.
# Запускать на новом компе:
#   bash shell-speedup/install.sh
#
# Правит ~/.zshrc и ~/.zprofile НА МЕСТЕ (не заменяет файлы целиком), всё
# идемпотентно — повторный запуск ничего не меняет. Перед правкой — бэкап .bak.
#
#   1. plugins=(...): убрать git, poetry, autojump.
#      - autojump: дважды форкает `brew --prefix` (~35 мс) + python на каждый cd;
#      - poetry: на КАЖДЫЙ старт шелла гоняет в фоне `poetry completions zsh`
#        (~270 мс python); автодополнение poetry остаётся из кэша oh-my-zsh;
#      - git: ~200 алиасов (~6 мс). Ветка/статус в промпте живут в ядре
#        oh-my-zsh (lib/git.zsh), а не в плагине — промпт не меняется.
#   2. zsh-abbr: закомментировать `source .../zsh-abbr.zsh` (~10 мс).
#   3. ~/.zprofile: `eval "$(brew shellenv)"` → его готовый вывод (без форка
#      brew на каждый логин-шелл, ~15 мс). Вывод генерится на ЭТОМ компе, так
#      что префикс (/opt/homebrew или /usr/local) будет свой. Исходная строка
#      остаётся закомментированной — вернуть можно, раскомментировав её.
#
# Итог на основном компе: промпт 118 → 58 мс, логин-шелл (⌘D) ~115 → ~45 мс.
set -euo pipefail

python3 - "$HOME" <<'PY'
import os, re, shutil, subprocess, sys

home = sys.argv[1]
zrc = os.path.join(home, ".zshrc")
zprof = os.path.join(home, ".zprofile")

def save(path, old, new):
    if new == old:
        return False
    shutil.copy(path, path + ".bak")
    with open(path, "w") as f:
        f.write(new)
    return True

# --- ~/.zshrc ------------------------------------------------------------------
if os.path.exists(zrc):
    src = open(zrc).read()
    new = src

    # 1. plugins=(...) — может быть и многострочным
    DROP = {"git", "poetry", "autojump"}
    def fix_plugins(m):
        words = m.group(1).split()
        kept = [w for w in words if w not in DROP]
        if kept == words:
            return m.group(0)
        removed = [w for w in words if w in DROP]
        print(f"  plugins: убираю {' '.join(removed)}")
        return "plugins=(" + " ".join(kept) + ")"
    new = re.sub(r"^plugins=\(([^)]*)\)", fix_plugins, new, count=1, flags=re.M)

    # 2. zsh-abbr — закомментировать незакомментированный source
    def fix_abbr(m):
        print("  zsh-abbr: комментирую подключение")
        return m.group(1) + "# " + m.group(2)
    new = re.sub(r"^([ \t]*)((?:source|\.)\s+.*zsh-abbr\.zsh.*)$", fix_abbr, new, flags=re.M)

    if save(zrc, src, new):
        print("✓ ~/.zshrc обновлён (бэкап ~/.zshrc.bak)")
    else:
        print("✓ ~/.zshrc уже в нужном виде — пропущено")
else:
    print("⚠️  ~/.zshrc не найден — пропускаю")

# --- ~/.zprofile ---------------------------------------------------------------
MARK = "# Inlined output of `brew shellenv`"
if os.path.exists(zprof):
    src = open(zprof).read()
    m = re.search(r'^[ \t]*eval\s+"\$\(\s*(\S*brew)\s+shellenv\s*\)"[ \t]*$', src, re.M)
    if MARK in src:
        print("✓ ~/.zprofile: brew shellenv уже встроен — пропущено")
    elif not m:
        print("✓ ~/.zprofile: строки eval \"$(brew shellenv)\" нет — пропущено")
    else:
        brew = m.group(1)
        if not os.path.isabs(brew):
            brew = shutil.which("brew") or brew
        try:
            out = subprocess.run([brew, "shellenv", "zsh"], capture_output=True,
                                 text=True, check=True).stdout.rstrip("\n")
        except (OSError, subprocess.CalledProcessError) as e:
            print(f"⚠️  не смог запустить `{brew} shellenv` ({e}) — ~/.zprofile не тронут")
            out = None
        if out:
            block = (MARK + " (saves spawning brew on every login shell).\n"
                     "# If Homebrew paths ever change, restore the line below or re-paste its output.\n"
                     "# " + m.group(0).strip() + "\n" + out)
            new = src[:m.start()] + block + src[m.end():]
            if save(zprof, src, new):
                print("✓ ~/.zprofile: brew shellenv встроен (бэкап ~/.zprofile.bak)")
else:
    print("✓ ~/.zprofile не найден — пропущено")
PY

echo
echo "✅ Готово. Новые табы подхватят сами, в открытых: exec zsh"
echo "   Опционально (больше не используются): brew uninstall autojump poetry zsh-abbr"
