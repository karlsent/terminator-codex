#!/bin/bash
# Codex-агент «Синтезатор»: собирает фидбеки и обновляет базу опыта агентов.
# Использование: ./agents/feedback_synth_agent.sh ["доп. указания"]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SH="${TERMINATOR_CONFIG_SH:-$HOME/.terminator-codex/task_agent_config.sh}"
if [ -f "$CONFIG_SH" ]; then
    source "$CONFIG_SH"
fi

EXTRA_DIRECTIVES="$1"
FEEDBACK_JSON="${FEEDBACK_FILE:-$HOME/.terminator-codex/launcher_feedback.json}"
EXPERIENCE_MD="${EXPERIENCE_FILE:-$HOME/.terminator-codex/agent_experience.md}"
NOTES_DIR="${NOTES_DIR:-$HOME/.terminator-codex/notes}"
mkdir -p "$NOTES_DIR/logs"
LOG_FILE="$NOTES_DIR/logs/experience_synth_$(date '+%Y-%m-%d_%H-%M-%S').log"

TMP_PROMPT="$(mktemp)"
{
  cat "$SCRIPT_DIR/feedback_synth_agent_prompt.md"
  echo ""
  echo "---"
  echo ""
  echo "## Текущий файл базы опыта (\`agent_experience.md\`)"
  echo ""
  echo '```markdown'
  if [ -f "$EXPERIENCE_MD" ]; then cat "$EXPERIENCE_MD"; fi
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "## Все записи фидбека"
  echo ""
  echo '```json'
  if [ -f "$FEEDBACK_JSON" ]; then cat "$FEEDBACK_JSON"; else echo "{}"; fi
  echo '```'
  if [ -n "$EXTRA_DIRECTIVES" ]; then
    echo ""
    echo "---"
    echo ""
    echo "## Дополнительные указания для этого прогона"
    echo ""
    echo "$EXTRA_DIRECTIVES"
  fi
} > "$TMP_PROMPT"
PROMPT=$(cat "$TMP_PROMPT")
rm -f "$TMP_PROMPT"

if [ -n "${GIT_REPO:-}" ] && [ -d "$GIT_REPO" ]; then
    cd "$GIT_REPO"
fi
[ -n "${NO_PROXY_DOMAINS:-}" ] && export no_proxy="$NO_PROXY_DOMAINS" && export NO_PROXY="$NO_PROXY_DOMAINS"

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

run_codex "read-only"
