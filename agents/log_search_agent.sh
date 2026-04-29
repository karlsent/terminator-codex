#!/bin/bash
# Поиск логов prod по ключевому слову для конкретной задачи
# Использование: ./scripts/log_search_agent.sh <TASK_ID> <keyword> [hours]
# Пример: ./scripts/log_search_agent.sh 2322836 "CSAT" 48
# По умолчанию [hours] = 336 (14 дней — максимум хранения логов)

set -e

TASK_ID=$1
KEYWORD=$2
HOURS=${3:-336}

if [ -z "$TASK_ID" ] || [ -z "$KEYWORD" ]; then
    echo "Использование: $0 <TASK_ID> <keyword> [hours]"
    echo "Пример: $0 2322836 \"CSAT\" 48"
    echo "По умолчанию hours=336 (14 дней)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SH="${TERMINATOR_CONFIG_SH:-$HOME/.terminator-codex/task_agent_config.sh}"
if [ -f "$CONFIG_SH" ]; then
    source "$CONFIG_SH"
fi

LOG_DIR="${NOTES_DIR:-$HOME/.terminator-codex/notes}/logs"
mkdir -p "$LOG_DIR"

OUTPUT_FILE="$LOG_DIR/${TASK_ID}_logs.md"
SEARCH_SCRIPT="${KUBE_LOG_SEARCH_SCRIPT:-/home/qweel/work/kube/search-bitrix-logs.sh}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Yandex Cloud и kubectl — напрямую, без прокси
export YC_PROFILE=qweel
export no_proxy="*"
export NO_PROXY="*"
export http_proxy=""
export https_proxy=""

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Поиск логов prod для задачи #$TASK_ID: \"$KEYWORD\" (за ${HOURS}ч)"

# Заголовок в выходной файл (добавить блок, не затирать предыдущие)
{
    echo ""
    echo "## Поиск: \"$KEYWORD\" (за ${HOURS} часов)"
    echo "_Запущено: $TIMESTAMP_"
    echo ""
} >> "$OUTPUT_FILE"

# Если файл только что создан — добавить заголовок в самое начало
if [ "$(wc -l < "$OUTPUT_FILE")" -le 5 ]; then
    TEMP=$(mktemp)
    {
        echo "# Логи продакшена — задача #${TASK_ID}"
        echo ""
        cat "$OUTPUT_FILE"
    } > "$TEMP"
    mv "$TEMP" "$OUTPUT_FILE"
fi

# Запустить поиск из директории логов чтобы временный файл search-bitrix-logs.sh
# сохранился туда же (он пишет в текущую директорию)
cd "$LOG_DIR"

SEARCH_OUTPUT=$("$SEARCH_SCRIPT" prod "$KEYWORD" "$HOURS" 2>&1) || true

echo "$SEARCH_OUTPUT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Итог в stdout
FOUND=$(echo "$SEARCH_OUTPUT" | grep -c "✓ НАЙДЕНО" || true)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Готово. Совпадений в подах: $FOUND"
echo "Результат: $OUTPUT_FILE"
