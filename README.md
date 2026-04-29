# Terminator Codex — веб-интерфейс для запуска Codex-агентов

Локальный веб-сервер для управления агентами на базе Codex CLI. Запускает Bitrix/PHP-агентов, стримит JSONL-логи в браузер, хранит историю запусков, собирает фидбек и обновляет базу опыта.

## Что умеет

- **Запуск агентов** — задачи, тесты, code review, написание тестов, синтез опыта
- **Codex JSONL logs** — живой просмотр событий `codex exec --json`
- **История** — запуски, результаты, полные логи, оценки и комментарии
- **Заметки** — Markdown-файлы агентов открываются прямо в интерфейсе
- **Синтезатор** — фидбеки обновляют `agent_experience.md`
- **Kubernetes helpers** — запуск тестов и read-only исследований через test-контур

## Требования

- Python 3.8+
- Codex CLI (`codex` в PATH и авторизация настроена)
- Flask (`pip install flask`)
- nginx — опционально, для домена `terminator-codex.agent`

## Установка

```bash
cd /home/qweel/programs/terminator-codex
python3 install.py
```

После установки открыть: **http://localhost:8765** или **http://terminator-codex.agent** при настроенном nginx.

## Структура

```text
terminator.py          # Flask-сервер, backend и HTML
install.py             # Установщик
agents/                # Codex agent shell wrappers и prompt-файлы
kube/                  # Скрипты для Kubernetes
static/                # Логотипы тем
```

Runtime-данные хранятся в `~/.terminator-codex/`:

```text
config.json
history.json
launcher_feedback.json
agent_experience.md
notes/
logs/
```

## Codex defaults

Агенты запускаются через `codex exec --json --color never`, prompt передаётся через stdin. По умолчанию используется `workspace-write` sandbox и `approval_policy="never"`, чтобы веб-запуски не зависали на интерактивных подтверждениях.
