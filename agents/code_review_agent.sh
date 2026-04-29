#!/bin/bash
# Codex-агент code review изменений в ветке
# Использование: ./agents/code_review_agent.sh <BRANCH> [TASK_ID] ["директивы"]

set -e

BRANCH=$1
TASK_ID=${2:-""}
EXTRA_DIRECTIVES=$3

if [ -z "$BRANCH" ]; then
    echo "Использование: $0 <BRANCH> [TASK_ID] ["директивы"]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SH="${TERMINATOR_CONFIG_SH:-$HOME/.terminator-codex/task_agent_config.sh}"
source "$CONFIG_SH"

RESULTS_DIR="${CODE_REVIEW_DIR:-$HOME/Documents/CodeReview}"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$RESULTS_DIR/${TIMESTAMP}_${BRANCH}.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Запуск Codex code review — ветка: $BRANCH${TASK_ID:+, задача #$TASK_ID}" | tee "$LOG_FILE"

export YC_PROFILE="${YC_PROFILE:-default}"
[ -n "${NO_PROXY_DOMAINS:-}" ] && export no_proxy="$NO_PROXY_DOMAINS" && export NO_PROXY="$NO_PROXY_DOMAINS"

PROMPT=$(sed \
    -e "s/{{BRANCH}}/$BRANCH/g" \
    -e "s/{{TASK_ID}}/$TASK_ID/g" \
    -e "s|BITRIX_REST_PLACEHOLDER|$BITRIX_REST_URL|g" \
    -e "s|{{RESULTS_DIR}}|$RESULTS_DIR|g" \
    -e "s/{{TIMESTAMP}}/$TIMESTAMP/g" \
    -e "s|{{GIT_REPO}}|$GIT_REPO|g" \
    -e "s|{{NOTES_DIR}}|${NOTES_DIR:-$HOME/.terminator-codex/notes}|g" \
    -e "s|{{ATTACHMENTS_DIR}}|${NOTES_DIR:-$HOME/.terminator-codex/notes}/attachments|g" \
    -e "s|{{YC_PROFILE}}|$YC_PROFILE|g" \
    "$SCRIPT_DIR/code_review_agent_prompt.md")

if [ -n "$EXTRA_DIRECTIVES" ]; then
    PROMPT="$PROMPT

---

## ⚡ Дополнительные директивы для этого запуска

$EXTRA_DIRECTIVES"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Директивы: $EXTRA_DIRECTIVES" | tee -a "$LOG_FILE"
fi

cd "$GIT_REPO"

run_codex() {
    local sandbox="${1:-${CODEX_SANDBOX:-workspace-write}}"
    shift || true
    local codex_bin="${CODEX_CMD:-codex}"
    local args=(exec --json --color never --sandbox "$sandbox" -c "approval_policy=\"${CODEX_APPROVAL:-never}\"")
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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex code review завершён. Лог: $LOG_FILE" | tee -a "$LOG_FILE"
