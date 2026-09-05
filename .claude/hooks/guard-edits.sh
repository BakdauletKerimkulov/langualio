#!/usr/bin/env bash
# PreToolUse hook — matcher: Edit|Write|MultiEdit|NotebookEdit
#
# Механический enforcement того, что в промптах команд записано как "hard rules".
# Промпт можно отрационализировать, exit code 2 — нельзя.
#
# Три уровня:
#   deny  — инфраструктура цикла. Агент не правит то, чем его проверяют.
#   ask   — правила доступа и миграции. Решает человек.
#   deny  — тесты, но ТОЛЬКО пока существует .gate/retry_active (см. ниже).
#
# Почему тесты защищены условно: во время TDD (RED) агент обязан писать тесты.
# Но когда gate упал и идёт retry, самый дешёвый способ "позеленеть" —
# ослабить тест вместо починки кода. Поэтому на время retry test/ read-only.

set -uo pipefail

input="$(cat)"
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"
[[ -n "$path" ]] || exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${path#"$root"/}"

deny() {
  printf 'ЗАБЛОКИРОВАНО: %s\n%s\n' "$rel" "$1" >&2
  exit 2
}

ask() {
  jq -nc --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# ---------------------------------------------------------------- deny: инфраструктура
case "$rel" in
  scripts/gate.sh)
    deny "gate — критерий твоей же проверки. Правится в agentic-coding-toolkit/templates/gate/, затем sync." ;;
  .claude/hooks/*|.claude/settings.json|.claude/agents/*)
    deny "Хуки, права и ревьюеры правятся человеком вручную. Опиши нужное изменение в ответе." ;;
  .gate/reviews/*.json)
    exit 0 ;;  # вердикты ревьюеров — единственное, что пишется в .gate/ не gate-скриптом
  .gate/*)
    deny "Допуск выдаёт только gate.sh. Запусти ./scripts/gate.sh." ;;
  ai_toolkit/*)
    deny "ai_toolkit — производная копия, sync её затрёт. Правь в agentic-coding-toolkit/ai_toolkit/, затем sync-toolkit.sh." ;;
  .github/workflows/*)
    deny "CI — внешний арбитр. Изменения в workflow только вручную." ;;
esac

# ---------------------------------------------------------------- ask: модель доступа
case "$rel" in
  firestore.rules|storage.rules)
    ask "Правка security rules. Это модель доступа — подтверди осознанно." ;;
  supabase/migrations/*)
    ask "Правка миграции. Уже применённые миграции менять нельзя — нужна новая. Подтверди." ;;
  firestore.indexes.json)
    ask "Правка composite-индексов Firestore. Подтверди." ;;
esac

# ---------------------------------------------------------------- deny: тесты во время retry
if [[ -f "$root/.gate/retry_active" ]]; then
  case "$rel" in
    test/*|integration_test/*|functions/test/*|supabase/tests/*|*_test.dart|*_test.ts|*.test.ts)
      deny "Идёт retry после красного gate — тесты заморожены.
Чини реализацию, а не проверку. Если тест действительно неверен, останови retry
и вынеси это отдельным решением через AskUserQuestion."
      ;;
  esac
fi

exit 0
