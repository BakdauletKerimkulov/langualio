# Code Review — langualio (2026-07-19)

Полное ревью проекта: Flutter-клиент, Supabase-бэкенд, документация, процессы. Приоритеты: 🔴 критично (безопасность/деньги/данные), 🟡 важно (архитектура/надёжность), 🟢 полировка.

## Общая оценка

Проект в хорошей форме: строгий feature-first, Riverpod полностью на codegen без legacy, репозитории возвращают доменные модели, GoRouter централизован, `print()` отсутствует, CI есть. Миграция `word_quiz_security.sql` — эталонная триада SECURITY DEFINER. Основные риски сосредоточены в трёх местах: server-authoritative поля, edge-функции и рассинхрон документации с кодом.

---

## 🔴 Критично

### C1. `generate-word-entry` не проверяет admin-роль
Спека `004-admin-panel-spec.md:101` требует проверку `app_metadata.role === 'admin'` с 403 — в коде её нет вообще. Любой аутентифицированный юзер жжёт квоту Claude API (реальные деньги).
Фикс: после `getUser(token)` — `if (user.app_metadata?.role !== 'admin') return jsonResponse({error: 'Forbidden'}, 403)`.

### C2. `cefr_level` пишется напрямую с клиента
`assessment_repository.dart:16` — клиент сам выставляет себе `cefr_level` и `assessment_completed` через `.update()`. Уровень определяет подбор контента; юзер может проставить любой.
Фикс: RPC `complete_assessment(answers)` — сервер валидирует ответы и сам вычисляет уровень; у клиента забрать grant на эти колонки.

### C3. Race condition в rate-limit обеих edge-функций
`chat` и `generate-word-entry`: read `count` → работа → write `count + 1`. Параллельные запросы читают одно значение — лимит обходится. Плюс инкремент после дорогого вызова.
Фикс: атомарный RPC-«билет» `try_consume_quota(kind, limit)` (insert ... on conflict do update ... where count < limit) **до** вызова Claude.

### C4. Невалидный model ID в chat
`chat/index.ts:5` — `claude-sonnet-4-5-20241022` смешивает версию и дату (Sonnet 4.5 = `20250929`). При невалидном ID каждый запрос чата падает в 502. Проверить и закрепить в конфиге/env.

### C5. Возможные секреты в репозитории
`supabase/.env.local` рядом с `.env.example` — проверить `.gitignore` и историю git. Если service_role key попадал в коммиты — ротировать.

---

## 🟡 Важно

### V1. Дублирование `core/` ↔ `shared/`
Идентичные копии common_widgets и constants в двух местах, обе живые (65 против 20 импортов). Консолидировать в `core/`, `shared/` удалить.

### V2. Supabase протекает выше data-слоя
- `app_router.dart:41` и `admin_provider.dart:13` — глобальный `Supabase.instance.client` мимо провайдера;
- `auth` — единственная фича без data-слоя, auth API вызывается из application (`auth_provider.dart:42,62`);
- `onboarding_state_provider.dart:39,65` — `.from('profiles')` в application-слое.
Фикс: `AuthRepository`, инъекция через `supabaseClientProvider` везде.

### V3. Дублированный `_mounted`-хак в 5+ нотифаерах
`try { state; return true; } catch (_) { return false; }` скопирован в home/grammar/word_quiz/add_word/admin. Вынести в один mixin (`lib/src/core/utils/notifier_mounted.dart`) — правило уже есть в `ai_toolkit/riverpod.md`, код ему не следует.

### V4. GoRouter без `refreshListenable`
Редиректы не переоцениваются при смене auth-сессии — логаут в другом табе/протухший токен не уводит на login. `ai_toolkit/gorouter.md:62` требует `GoRouterRefreshStream` — не подключён.

### V5. Тихое проглатывание ошибок
- `quiz_attempt_repository.saveAttempt` — попытка теряется молча (лог и всё);
- `chat_repository.fetchMessages:75` — при ошибке возвращает пустоту вместо проброса.
Прогресс юзера — не то, что можно терять молча: пробрасывать в AsyncError или ставить в retry-очередь.

### V6. Дублирование edge-функций, нет `_shared/`
`jsonResponse`, CORS, auth-паттерн, rate-limit скопированы 1:1 между `chat` и `generate-word-entry`; env-guard'ы непоследовательны (chat — graceful 500, generate — краш). Вынести в `supabase/functions/_shared/`.

### V7. Нет тестов бэкенда, CI покрывает только Flutter
Ни одного теста SQL/RPC (а `upsert_word_learning_progress` содержит нетривиальный greedy-chain алгоритм) и edge-функций. CI не гоняет `deno test` / `supabase db lint` / реплей миграций.

### V8. Документация расходится с кодом
- `ai_docs/PROJECT.md` — схема БД уровня Phase 7: перечисляет дропнутые `practice_*`, не знает про word_quiz/admin/assessment/`generate-word-entry`; описывает SSE-стриминг чата, которого нет в коде;
- `README.md` — заглушка flutter create;
- `PLAN.md` — исторический документ, не living-doc.
Агент, читающий `ai_docs/` как источник истины, получает ложную картину — это хуже отсутствия доков.

---

## 🟢 Полировка

1. Мусор: пустая миграция `20260504190931_new-migration.sql`, `snippets/Untitled query 498.sql` (ручной UPDATE ролей мимо whitelist), `scripts/output/` батчи в репо.
2. `admin_panel`: триггер роли на `BEFORE UPDATE` без INSERT (нужен ре-логин — задокументировано, но JWT живёт до часа после снятия роли); GRANT после `CREATE OR REPLACE get_todays_words` неявный.
3. Модели без единого стандарта: freezed только в word_quiz, остальное — ручные классы, парсинг то в модели, то в репозитории. Зафиксировать правило и привести к нему.
4. Файлы >300 строк: `add_word_screen.dart` (340), `word_quiz_screen.dart` (301); фильтрация коллекций в build у `grammar_screen.dart:74`, `word_quiz_home_screen.dart:96`.
5. 46 мест с хардкодом отступов мимо `Sizes`; `ref.watch` в теле метода (`word_pool_provider.dart:15`, `quiz_home_notifier.dart:74`).
6. `error_logger.dart` — заглушка: подключить Sentry/Crashlytics.
7. `app_config` объявлен «admin-only write», но политики записи нет ни у кого — комментарий врёт; значения меняются только мимо истории.
8. Скрипты ETL с захардкоженными абсолютными путями (`extract_words_from_pdf.py`).

## Что образцово (сохранять как паттерн)

`word_quiz_security.sql` (триада SECURITY DEFINER), `word_meanings_jsonb.sql` (zero-downtime JSONB-миграция), чистые статические мапперы в репозиториях (`HomeRepository.mapToUserProgress`), sanitization контекста в chat (строки 202–218), `AsyncErrorLogger` как ProviderObserver, resumable-батчи в `generate_b1_json.py`.

## Рекомендуемый порядок работ

1. C1 + C3 (одна миграция `try_consume_quota` + правки двух функций) → 2. C4, C5 → 3. C2 (RPC assessment) → 4. V1, V3, V4 (механические, по правилам toolkit) → 5. V2 (AuthRepository) → 6. V6 (_shared) → 7. V8 (актуализация PROJECT.md) → 8. V7 (тесты бэкенда + CI) → 9. полировка.
