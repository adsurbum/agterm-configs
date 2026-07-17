# agterm-configs

Мои настройки терминала **agterm**: кастомные шорткаты, скрипты к ним,
ghostty-конфиги, тема, плюс отдельная система «каждый таб/панель помнит свою
Claude-сессию + авто-резюме» (нужна для ⌘B — форк Claude).

Всё портируемо: скрипты используют `$HOME` и `$AGT_*`, установщик сам
подставляет префикс Homebrew (arm64 `/opt/homebrew` ↔ Intel `/usr/local`).

## Установка на новом Mac

```sh
# 1. поставить agterm.app в /Applications, затем в самом agterm:
#    Help ▸ Install Command Line Tool…   (ставит agtermctl на PATH)

# 2. клонировать этот репозиторий
git clone git@github.com:adsurbum/agterm-configs.git
cd agterm-configs

# 3. основные настройки agterm (keymap, скрипты, ghostty, тема, fribidi)
bash install.sh

# 4. (опционально) ⌘B «форк Claude» + авто-резюме табов.
#    Ставить ПОСЛЕ того как настроен Claude Code (залогинен) на этом компе:
bash claude-tab-resume/install.sh

# 5. перезапустить agterm, чтобы точно подхватились меню-шорткаты
```

## Что в репозитории

| Путь | Что это | Куда ставится |
|------|---------|---------------|
| `config-agterm/keymap.conf` | все шорткаты (см. ниже) | `~/.config/agterm/keymap.conf` |
| `config-agterm/scripts/` | скрипты к шорткатам | `~/.config/agterm/scripts/` |
| `config-ghostty/config` | глобальный ghostty-конфиг | `~/.config/ghostty/config` |
| `app-support/` | тема, скролл, right-click | `~/Library/Application Support/agterm/` |
| `claude-tab-resume/` | хуки + zshrc для ⌘B и авто-резюме | `~/.claude/`, `~/.zshrc` |

## Шорткаты (англ. / рус. раскладка)

| Клавиши | Действие |
|---------|----------|
| ⌘N / ⌘Т | новая сессия в текущей директории |
| ⌘⌥⇧N | новая сессия в `$HOME` |
| ⌘B / ⌘И | новый таб с форком Claude-сессии этой панели |
| ⌘] / ⌘Ъ | фокус на правую панель (откроет сплит, если его нет) |
| ⌘R / ⌘К | переименовать сессию |
| ⌘⇧O / ⌘⇧Щ | открыть выделенный путь/URL через `open` |
| ⌘⇧H / ⌘⇧Р | показать выделение (или весь экран) с правильным порядком RTL (иврит) |
| ⌘T / ⌘Е | переключить тему (Solarized Dark ↔ Light) |
| ⌘Ц | закрыть таб (русский дубль ⌘W, с учётом overlay/quick/zoom) |

Плюс русские дубли для встроенных: навигация по сессиям, сплит, scratch,
quick terminal, workspace, флаг, поиск, дашборд.

## Зависимости

- **agterm.app** + `agtermctl` (ставится из меню agterm)
- **Homebrew** и **fribidi** (`brew install fribidi`) — для ⌘⇧H (иврит/RTL);
  ставится автоматически из `install.sh`

## Тонкости

- `install.sh` перезапишет существующий `~/.config/ghostty/config` (со старого
  сделает `config.bak`).
- `claude-tab-resume/install.sh` идемпотентен: вмерживает hook-записи в
  `~/.claude/settings.json` НЕ трогая другие твои хуки (бэкап `.bak`), а блоки в
  `~/.zshrc` добавляет по маркерам и не дублирует при повторном запуске.
- agterm-овская настройка «Restore running commands on restart» должна быть
  ВЫКЛЮЧЕНА — авто-резюме табов заменяет её и не должно от неё зависеть.

## Обновить конфиги ИЗ этого репозитория (на исходном компе)

Файлы в репо — копии; правишь ты живые (`~/.config/agterm/...`). Чтобы
синхронизировать назад, скопируй изменённое в клон и запушь. Или добавь свой
скрипт `pull-from-live.sh` — пока делается вручную.
