#!/usr/bin/python3
"""Подгонка ширины сайдбара agterm под самый длинный ярлык + слот индикатора.

У agterm нет API ширины, но sidebarWidth — живой @AppStorage-дефолт: запись в
него меняет ширину сайдбара запущенного приложения на лету, без перезапуска.
Пишем ТОЛЬКО при изменении, иначе @AppStorage дёргает перелейаут вхолостую.

Режимы:
  fit-sidebar.py            один прогон — для хуков (старт / новый таб / ⌘B-форк
                            через SessionStart, ⌘K-rename через rename-session.sh)
  fit-sidebar.py --watch    демон под launchd: опрашивает дерево раз в INTERVAL.
                            Нужен, потому что встроенное inline-переименование
                            agterm (даблклик) не даёт хука — событий rename
                            наружу нет. Опрос дешёвый: один долгоживущий процесс.
"""
import json, re, subprocess, sys, time, unicodedata

AGTERMCTL = "/opt/homebrew/bin/agtermctl"
DOMAIN = "com.umputun.agterm"

# --- тюнинг -----------------------------------------------------------------
PER_CHAR = 7.0      # точек на колонку для шрифта сайдбара (~13pt system)
BASE = 40           # левый отступ + индент + слот индикатора + правый отступ
NAME_CAP = 34       # длиннее — не учитываем (случайные длинные title не раздувают)
MINW, MAXW = 170, 460
INTERVAL = 1.5      # сек между опросами в режиме --watch
# ----------------------------------------------------------------------------

LEAD = re.compile(r'^[\s⠀-⣿✳✨●○•]+')  # ведущий индикатор: спиннер/braille/✳/точки
PROMPT = re.compile(r'^\S+@\S+:')          # user@host: — некастомный заголовок шелла


def cols(label):
    s = LEAD.sub('', label or '').strip()
    if not s or PROMPT.match(s):
        return 0
    w = sum(2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1 for c in s)
    return min(w, NAME_CAP)


def widest_columns():
    try:
        out = subprocess.run([AGTERMCTL, "tree", "--json"],
                             capture_output=True, text=True, timeout=5).stdout
        tree = json.loads(out)["result"]["tree"]
    except Exception:
        return None  # agterm не запущен / сокет недоступен — молча пропускаем тик
    labels = []
    for ws in tree.get("workspaces", []):
        labels.append(ws.get("name", ""))
        for se in ws.get("sessions", []):
            labels.append(se.get("name", ""))
            labels.append(se.get("title", ""))
    return max((cols(x) for x in labels), default=0)


def current_width():
    try:
        out = subprocess.run(["defaults", "read", DOMAIN, "sidebarWidth"],
                             capture_output=True, text=True).stdout.strip()
        return float(out)
    except (ValueError, subprocess.SubprocessError):
        return None


def fit_once():
    mw = widest_columns()
    if mw is None:
        return
    width = max(MINW, min(MAXW, round(BASE + PER_CHAR * mw)))
    cur = current_width()
    if cur is None or abs(cur - width) >= 1:
        subprocess.run(["defaults", "write", DOMAIN, "sidebarWidth", "-float", str(width)],
                       check=False)


def main():
    if "--watch" in sys.argv[1:]:
        while True:
            fit_once()
            time.sleep(INTERVAL)
    else:
        fit_once()


if __name__ == "__main__":
    main()
