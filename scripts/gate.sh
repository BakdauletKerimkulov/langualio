#!/usr/bin/env bash
# scripts/gate.sh — единственный критерий "фаза готова" для Flutter + Supabase.
#
# Раскатывается из agentic-coding-toolkit (templates/gate/supabase.sh).
# Правки вносить в базе; sync затирает файл только с --force-scripts.
#
#   ./scripts/gate.sh              # все тиры
#   ./scripts/gate.sh --fast       # только тир 0 (для инкрементальной проверки внутри фазы)
#   ./scripts/gate.sh --no-approve # не писать допуск (для CI)
#
# Exit code — единственный источник истины. 0 = зелено.
# При успехе пишет .gate/approved_sha — допуск, привязанный к текущему дифу.
# Любая последующая правка кода делает допуск невалидным (см. .claude/hooks).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAST=0
APPROVE=1
for arg in "$@"; do
  case "$arg" in
    --fast)       FAST=1 ;;
    --no-approve) APPROVE=0 ;;
    -h|--help)    sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            printf 'error: unknown flag: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

mkdir -p .gate
LOG="$ROOT/.gate/last_run.log"
: > "$LOG"

FAILED=()

# Полный вывод — в лог, в stdout — только выжимка.
# В retry-цикле агент читает stdout на каждой итерации; отдавать ему целиком
# вывод flutter test или psql шесть раз подряд дороже, чем сама починка.
step() {
  local name="$1"; shift
  printf '\n\033[1m▶ %s\033[0m\n' "$name"

  local out rc
  out="$("$@" 2>&1)"; rc=$?
  { printf '\n===== %s (exit %d) =====\n%s\n' "$name" "$rc" "$out"; } >> "$LOG"

  if [[ $rc -eq 0 ]]; then
    printf '\033[32m✓ %s\033[0m\n' "$name"
    return
  fi

  printf '\033[31m✗ %s\033[0m\n' "$name"

  # Приоритет — маркеры тест-раннера и компилятора. Логи самого приложения
  # (в них тоже бывает слово ERROR: тесты ветвей ошибок их печатают намеренно)
  # не должны вытеснять настоящий отчёт о падении.
  local digest
  digest="$(printf '%s\n' "$out" \
    | grep -aE '^\s*(FAIL|✗|×|❯)|AssertionError|Expected:|Received:|Actual:|error •|^\s*Error: .*\.dart|[0-9]+ failed|Test Files|Tests\s+[0-9]|^psql:.*ERROR' \
    | head -20)"
  [[ -n "$digest" ]] || digest="$(printf '%s\n' "$out" | grep -av '^\s*$' | tail -20)"
  printf '%s\n' "$digest" | sed 's/\x1b\[[0-9;]*m//g'
  printf '  … полный вывод шага: .gate/last_run.log\n'
  FAILED+=("$name")
}

# ---------------------------------------------------------------- tier 0
# Дёшево и детерминированно. Гоняется всегда, в том числе внутри фазы.

# --output=none обязателен: без него dart format ПЕРЕЗАПИСЫВАЕТ файлы.
# Gate обязан проверять, а не менять рабочее дерево — иначе он сам себе
# ломает допуск (хеш дерева меняется) и подмешивает шум в диф фичи.
step "format"      dart format --output=none --set-exit-if-changed lib test
step "analyze"     flutter analyze --fatal-infos --fatal-warnings
step "custom_lint" dart run custom_lint
step "test"        flutter test --exclude-tags golden

if [[ $FAST -eq 1 ]]; then
  if [[ ${#FAILED[@]} -gt 0 ]]; then
    printf '\n\033[31mgate --fast: FAIL\033[0m — %s\n' "${FAILED[*]}"
    exit 1
  fi
  printf '\n\033[32mgate --fast: PASS\033[0m (тир 1 не запускался)\n'
  exit 0
fi

# ---------------------------------------------------------------- tier 1
# Backend. Требует Docker + supabase CLI + deno. Гоняется в конце фазы.
# Не запускается, если тир 0 красный.

if [[ ${#FAILED[@]} -gt 0 ]]; then
  printf '\n\033[31mgate: FAIL (тир 0)\033[0m — %s\n' "${FAILED[*]}"
  printf 'тир 1 пропущен: сначала зелёный тир 0\n'
  exit 1
fi

# Edge functions: чистые хелперы и промпты. Дёшево, поэтому первым.
if [[ -d supabase/functions ]] && command -v deno >/dev/null 2>&1; then
  step "deno:test" deno test supabase/functions/ --allow-env --allow-read
fi

# RLS + RPC контракты. Единственная реальная проверка правил доступа —
# гонять только против локального стека, никогда против прод-проекта.
if [[ -d supabase/tests ]] && command -v supabase >/dev/null 2>&1; then
  run_sql_suite() {
    supabase start >/dev/null 2>&1 || true
    supabase db reset --no-seed >/dev/null || return 1

    local db_url; db_url="$(supabase status -o env 2>/dev/null | grep '^DB_URL=' | cut -d= -f2- | tr -d '"')"
    [[ -n "$db_url" ]] || { printf 'не получил DB_URL из supabase status\n' >&2; return 1; }

    local rc=0 f
    for f in supabase/tests/*.sql; do
      [[ -e "$f" ]] || continue
      printf '  · %s\n' "$(basename "$f")"
      psql "$db_url" -v ON_ERROR_STOP=1 -f "$f" >/dev/null || rc=1
    done
    return $rc
  }
  step "rls+rpc:test" run_sql_suite
elif [[ -d supabase/tests ]]; then
  printf '\n\033[33m! supabase CLI не найден — RLS-тесты пропущены\033[0m\n'
  FAILED+=("rls:test (supabase CLI отсутствует)")
fi

# ---------------------------------------------------------------- вердикт

if [[ ${#FAILED[@]} -gt 0 ]]; then
  printf '\n\033[31mgate: FAIL\033[0m\n'
  printf '  ✗ %s\n' "${FAILED[@]}"
  rm -f .gate/approved_sha
  exit 1
fi

printf '\n\033[32mgate: PASS\033[0m — все тиры зелёные\n'

if [[ $APPROVE -eq 1 ]] && git rev-parse --git-dir >/dev/null 2>&1; then
  mkdir -p .gate
  # Допуск привязан к содержимому рабочего дерева, а не ко времени.
  # Правка одного символа после gate → хеш другой → допуск протух.
  # .gate/ исключён: файл допуска сам untracked и иначе попал бы в собственный хеш
  {
    git diff HEAD -- . ':!.gate'
    git ls-files --others --exclude-standard -- . ':!.gate' | sort | xargs -r cat
  } | shasum -a 256 | cut -d' ' -f1 > .gate/approved_sha
  printf 'допуск записан: .gate/approved_sha (%s)\n' "$(cut -c1-12 .gate/approved_sha)"
fi

exit 0
