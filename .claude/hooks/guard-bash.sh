#!/usr/bin/env bash
# PreToolUse hook — matcher: Bash
#
# Закрывает два обхода guard-edits.sh и вводит допуск на git-мутации.
#
# 1. Правка защищённых файлов через shell (sed -i, cat >, rm, mv, tee).
# 2. git commit / push без валидного допуска от gate.sh.
# 3. push и любые мутации main.
#
# Допуск (.gate/approved_sha) привязан к хешу рабочего дерева. Правка одного
# символа после зелёного gate делает его невалидным — это то, что мешает
# агенту прогнать проверки, "ещё чуть-чуть подправить" и закоммитить непроверенное.

set -uo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
[[ -n "$cmd" ]] || exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"

deny() {
  printf 'ЗАБЛОКИРОВАНО\n%s\n' "$1" >&2
  exit 2
}

# ---------------------------------------------------------------- защищённые пути через shell
if printf '%s' "$cmd" | grep -qE '(^|[;&|]|\s)(rm|mv|cp|tee|sed\s+-i|truncate)\b.*\.(gate|claude)/' \
|| printf '%s' "$cmd" | grep -qE '>\s*\.?(gate|claude)/' \
|| printf '%s' "$cmd" | grep -qE '(^|[;&|]|\s)(rm|mv|sed\s+-i|truncate)\b.*scripts/gate\.sh'; then
  deny "Попытка изменить инфраструктуру цикла (.gate/, .claude/, scripts/gate.sh) через shell.
Эти файлы правит человек. Опиши нужное изменение словами."
fi

# ---------------------------------------------------------------- git
if printf '%s' "$cmd" | grep -qE '(^|[;&|]|\s)git\s'; then

  # main неприкосновенен: PR — единственный путь в него
  if printf '%s' "$cmd" | grep -qE 'git\s+push\b.*\b(main|master)\b' \
  || printf '%s' "$cmd" | grep -qE 'git\s+push\s+(-\S+\s+)*\S+\s+HEAD:(main|master)'; then
    deny "Прямой push в main запрещён. Работай в ветке и открывай PR (/git-push-make-pr)."
  fi

  if printf '%s' "$cmd" | grep -qE 'git\s+push\b.*--force|git\s+push\b.*-f(\s|$)'; then
    deny "Force-push запрещён без явного решения человека."
  fi

  # commit/push — только с действующим допуском под текущий диф
  if printf '%s' "$cmd" | grep -qE 'git\s+(commit|push)\b'; then
    branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
      deny "Ты на $branch. Создай ветку: git switch -c feat/{NNN}-{name}"
    fi

    approved_file="$root/.gate/approved_sha"
    if [[ ! -f "$approved_file" ]]; then
      deny "Нет допуска. Запусти ./scripts/gate.sh и добейся PASS."
    fi

    # Должно совпадать с расчётом в scripts/gate.sh, включая исключение .gate/
    current="$(
      {
        git -C "$root" diff HEAD -- . ':!.gate'
        git -C "$root" ls-files --others --exclude-standard -- . ':!.gate' | sort | \
          while IFS= read -r f; do cat "$root/$f" 2>/dev/null; done
      } | shasum -a 256 | cut -d' ' -f1
    )"
    approved="$(cat "$approved_file")"

    if [[ "$current" != "$approved" ]]; then
      deny "Допуск протух: рабочее дерево изменилось после последнего зелёного gate.
Перезапусти ./scripts/gate.sh — коммитить можно только проверенное состояние."
    fi
  fi
fi

exit 0
