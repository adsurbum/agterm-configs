#!/usr/bin/python3
"""Запасные («прогретые») claude-сессии для ⌘D (new-claude.sh).

Старт claude занимает ~0.5 с. Чтобы ⌘D открывал таб мгновенно, держим в
фоновом воркспейсе SPARES_WS уже запущенный claude для каждой из MAX_DIRS
последних директорий, где жали ⌘D. ⌘D забирает запаску своей директории
(переносит таб к себе), а после — в фоне ставит на её место новую.

claude привязан к директории запуска, поэтому запаска годится только для своей
cwd; в чужой директории ⌘D стартует claude обычным путём и оставляет запаску
на следующий раз. Запаски старше MAX_AGE не отдаём: у claude контекст (git
status, CLAUDE.md, настройки/плагины) снимается на старте и протухает.

Режимы (env от keymap-раннера: $AGT_WINDOW_ID, $AGT_SOCKET):
  claude-spare.py claim  <cwd>  вывести id запаски для cwd и снять её с учёта;
                                exit 1, если живой и свежей нет
  claude-spare.py refill <cwd>  отметить cwd как свежую, поставить для неё
                                запаску, лишние (сверх MAX_DIRS) закрыть
"""
import fcntl, json, os, subprocess, sys, time

AGTERMCTL = "/opt/homebrew/bin/agtermctl"
SPARES_WS = "spares"
CLAUDE_CMD = "zsh -lic 'claude; exec zsh -l'"  # как в new-claude.sh
MAX_DIRS = 3
MAX_AGE = 2 * 3600  # сек
STATE_DIR = os.path.expanduser("~/.cache/agterm-claude-spares")
STATE = os.path.join(STATE_DIR, "state.json")

WINDOW = os.environ.get("AGT_WINDOW_ID", "")
SOCKET = os.environ.get("AGT_SOCKET", "")


def ctl(*args):
    cmd = [AGTERMCTL, *args]
    if WINDOW and args[0] != "window":
        cmd += ["--window", WINDOW]
    if SOCKET:
        cmd += ["--socket", SOCKET]
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()


def spare_ids():
    """id сессий, которые сейчас лежат в воркспейсе запасок этого окна."""
    tree = json.loads(ctl("tree", "--json"))["result"]["tree"]
    return {s["id"].upper()
            for ws in tree["workspaces"] if ws.get("name") == SPARES_WS
            for s in ws["sessions"]}


def load():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def save(entries):
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(entries, f, indent=1)
    os.replace(tmp, STATE)


def live(entries):
    """Забыть запаски этого окна, которых больше нет в воркспейсе запасок
    (закрыты руками, пропали после рестарта agterm). Сама cwd остаётся в
    списке свежих — refill поставит новую."""
    alive = spare_ids()
    for e in entries:
        if e["window"] == WINDOW and e["sid"] and e["sid"].upper() not in alive:
            e["sid"] = None
    return entries


def claim(cwd, entries):
    now = time.time()
    for e in entries:
        if e["window"] == WINDOW and e["cwd"] == cwd and e.get("sid"):
            sid, fresh = e["sid"], now - e["created"] < MAX_AGE
            e["sid"] = None  # cwd остаётся в списке свежих — refill поставит новую
            if not fresh:
                ctl("session", "close", "--target", sid)
                return None
            return sid
    return None


def refill(cwd, entries):
    now = time.time()
    mine = next((e for e in entries if e["window"] == WINDOW and e["cwd"] == cwd), None)
    if mine is None:
        mine = {"window": WINDOW, "cwd": cwd, "sid": None, "created": 0}
        entries.append(mine)
    mine["used"] = now
    if not mine["sid"]:
        mine["sid"] = ctl("session", "new", "--no-select", "--workspace-name", SPARES_WS,
                          "--create-workspace", "--cwd", cwd, "--command", CLAUDE_CMD)
        mine["created"] = now

    ours = sorted((e for e in entries if e["window"] == WINDOW),
                  key=lambda e: e["used"], reverse=True)
    stale = [e for e in ours[MAX_DIRS:] if e["sid"]]
    if stale:
        targets = [a for e in stale for a in ("--target", e["sid"])]
        ctl("session", "close", *targets)
    drop = {id(e) for e in ours[MAX_DIRS:]}
    return [e for e in entries if id(e) not in drop]


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("claim", "refill") or not WINDOW:
        sys.exit("usage: claude-spare.py claim|refill <cwd>  (needs $AGT_WINDOW_ID)")
    mode, cwd = sys.argv[1], os.path.realpath(sys.argv[2])
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)  # два ⌘D подряд не должны забрать одну запаску
        entries = live(load())
        if mode == "claim":
            sid = claim(cwd, entries)
            save(entries)
            if not sid:
                sys.exit(1)
            print(sid)
        else:
            save(refill(cwd, entries))


if __name__ == "__main__":
    main()
