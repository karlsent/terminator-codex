#!/bin/bash
# Запуск Codex-агента тестирования PHPUnit
# Использование: ./agents/test_agent.sh [фильтр]

set -e

FILTER=$1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SH="${TERMINATOR_CONFIG_SH:-$HOME/.terminator-codex/task_agent_config.sh}"
source "$CONFIG_SH"

RESULTS_DIR="${TEST_RESULTS_DIR:-$HOME/Documents/TestResult}"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LABEL=${FILTER:-all}
LOG_FILE="$RESULTS_DIR/${TIMESTAMP}_${LABEL}.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Запуск Codex-агента тестирования — фильтр: ${FILTER:-ВСЕ ТЕСТЫ}" | tee "$LOG_FILE"

export YC_PROFILE="${YC_PROFILE:-default}"
[ -n "${NO_PROXY_DOMAINS:-}" ] && export no_proxy="$NO_PROXY_DOMAINS" && export NO_PROXY="$NO_PROXY_DOMAINS"

PROMPT=$(sed \
    -e "s|{{FILTER}}|${FILTER}|g" \
    -e "s|{{RESULTS_DIR}}|${RESULTS_DIR}|g" \
    -e "s|{{LOG_FILE}}|${LOG_FILE}|g" \
    -e "s|{{TIMESTAMP}}|${TIMESTAMP}|g" \
    -e "s|{{GIT_REPO}}|$GIT_REPO|g" \
    -e "s|{{KUBE_UPLOAD_SCRIPT}}|$KUBE_UPLOAD_SCRIPT|g" \
    -e "s|{{KUBE_RUN_SCRIPT}}|$KUBE_RUN_SCRIPT|g" \
    -e "s|{{YC_PROFILE}}|$YC_PROFILE|g" \
    "$SCRIPT_DIR/test_agent_prompt.md")

cd "$GIT_REPO"

run_codex() {
    local sandbox="${1:-${CODEX_SANDBOX:-workspace-write}}"
    shift || true
    local codex_bin="${CODEX_CMD:-codex}"
    local args=(exec --json --color never --sandbox "$sandbox" -c "approval_policy=\"${CODEX_APPROVAL:-never}\"" -c "sandbox_workspace_write.network_access=true")
    if [ -n "${CODEX_MODEL:-}" ]; then args+=(-m "$CODEX_MODEL"); fi
    if [ -n "${CODEX_PROFILE:-}" ]; then args+=(-p "$CODEX_PROFILE"); fi
    if [ -n "${GIT_REPO:-}" ]; then args+=(-C "$GIT_REPO"); fi
    for extra_dir in "${NOTES_DIR:-}" "${TEST_RESULTS_DIR:-}" "${CODE_REVIEW_DIR:-}" "${KUBE_LOGS_DIR:-}" /tmp; do
        if [ -n "$extra_dir" ] && [ -d "$extra_dir" ]; then
            args+=(--add-dir "$extra_dir")
        fi
    done
    printf '%s' "$PROMPT" | "$codex_bin" "${args[@]}" - 2>&1 | tee -a "$LOG_FILE"
}

run_codex "${CODEX_SANDBOX:-workspace-write}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex-агент завершил работу. Лог: $LOG_FILE" | tee -a "$LOG_FILE"
