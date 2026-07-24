# Langualio

Мобильное приложение для изучения английского языка. Язык интерфейса — русский, учебный контент — английский.

## Стек

- **Frontend:** Flutter (Dart SDK ^3.9.2)
- **State management:** Riverpod 2.6.1 (flutter_riverpod + riverpod_annotation + riverpod_generator)
- **Навигация:** go_router 15.1.2
- **Backend:** Supabase (auth, database, Edge Functions)
- **БД:** PostgreSQL (через Supabase, миграции в `supabase/migrations/`)
- **Edge Functions:** Supabase Functions (Deno/TypeScript, `supabase/functions/`)
- **AI:** Claude Sonnet (claude-sonnet-4-20250514) через Anthropic API
- **Локальное хранилище:** SharedPreferences (обёртка `LocalStorage`) + Drift (SQLite для user words)
- **Шрифт:** Nunito (Google Fonts), Material 3

## Платформы

Android, iOS, Web.

---

## Бизнес-логика и домен

### Ключевые сущности

| Сущность | Описание | Таблица в БД |
|---|---|---|
| **AppUser** | Авторизованный пользователь (id, email, nickname) | `profiles` (auto-create trigger) |
| **UserProgress** | Прогресс: уровень, XP, streak, дневные цели | `profiles` + `daily_goals` |
| **UserProfile** | Расширенный профиль со статистикой и ачивками | `profiles` |
| **ChatMessage** | Сообщение в чате (role, text, context) | `chat_messages` |
| **GrammarItem** | Грамматическое правило с примерами и статусом | `grammar_items` + `user_grammar_progress` |
| **WordEntry** | Слово с множественными значениями (multi-meaning model) | `daily_words` (meanings jsonb) |
| **WordQuizAttempt** | Попытка ответа в word quiz | `word_quiz_attempts` |
| **WordLearningProgress** | Прогресс изучения слова (greedy-chain алгоритм) | `word_learning_progress` |
| **DailyGoal** | Дневная цель с XP-наградой | `daily_goals` |
| **Achievement** | Достижение (title, isUnlocked) | — (пока mock) |
| **AssessmentQuestion** | Вопрос теста уровня | `assessment_questions` (seed data, 12 вопросов) |
| **AssessmentResult** | Результат теста (определяется server-side RPC) | `profiles.cefr_level` |

### Система прогресса

- **Уровни:** числовые (1, 2, 3...), не CEFR (A1–C2)
- **XP:** зарабатывается за правильные ответы (10 XP за ответ), выполнение дневных целей
- **Левелинг:** currentXp / targetXp — при достижении targetXp уровень растёт
- **Streak:** количество дней подряд, отслеживается через `last_active_date`
- **Дневные цели:** список задач на день, каждая с XP-наградой

### Word Quiz

- **Два режима:** en→ru (перевод) и ru→en (слово по переводу)
- **Multi-meaning:** слово может иметь несколько значений; при загрузке сессии случайно выбирается один `meaningIndex` на каждое слово
- **Варианты ответа:** 1 правильный + 3 distractor'а из текущего пула слов
- **Прогресс изучения:** `upsert_word_learning_progress` RPC — greedy-chain алгоритм (3+ правильных дня с промежутками 1–3 дня → слово "выучено")
- **Источник слов:** asset-файл (`b1_words.json`) + пользовательские слова (Drift/SQLite, добавляются через admin панель)

### Система грамматики

- **Статусы:** `completed` → `unlocked` → `locked` (линейная прогрессия)
- **Прогресс:** rulesMastered / totalRules (e.g., "8/8")
- **Контент:** категория, формула, примеры с подсветкой (before | highlight | after)

### Лимиты чата

- **Дневной лимит:** 20 сообщений/день (настраивается через `app_config`)
- **Атомарная квота:** `try_consume_quota` RPC (предотвращает race conditions)
- **Локальный кеш:** максимум 50 сообщений в SharedPreferences
- **История для контекста:** последние 20 сообщений отправляются в Claude

---

## Supabase-схема

### Таблицы

| Таблица | Назначение | RLS |
|---|---|---|
| `profiles` | Профиль пользователя (nickname, level, xp, streak, cefr_level, assessment_completed) | SELECT: own; UPDATE: own (только nickname, avatar_url — cefr_level, assessment_completed server-only) |
| `daily_goals` | Дневные цели с XP | SELECT/INSERT/UPDATE: own |
| `grammar_items` | Контент грамматики (read-only) | SELECT: authenticated |
| `user_grammar_progress` | Прогресс по грамматике (unique: user_id + grammar_id) | SELECT/INSERT/UPDATE: own |
| `daily_words` | Словарный контент (word, meanings jsonb, level, status) | Admins: full CRUD; Users: SELECT published only |
| `daily_word_sets` | Связь слов с датами показа | SELECT: authenticated |
| `word_quiz_attempts` | Попытки ответов в word quiz | SELECT/INSERT: own |
| `word_learning_progress` | Прогресс изучения слов (greedy-chain) | SELECT/INSERT/UPDATE: own |
| `chat_messages` | История чата | SELECT/INSERT/DELETE: own |
| `app_config` | Конфигурация (лимиты, константы) | SELECT: authenticated (write: нет клиентских политик) |
| `user_daily_usage` | Счётчик сообщений и генераций (unique: user_id + date) | SELECT: own (INSERT/UPDATE отозваны — запись только через `try_consume_quota` RPC) |
| `admin_emails` | Whitelist email-адресов для автоматической выдачи админ-роли | Нет публичных политик (service role only) |
| `assessment_questions` | Банк вопросов теста уровня (12 seed-вопросов) | SELECT: authenticated |

### RPC-функции

| Функция | Назначение | Доступ |
|---|---|---|
| `get_todays_words()` | Слова дня (join daily_words + daily_word_sets по дате Asia/Almaty) | authenticated |
| `upsert_word_learning_progress(p_word_id, p_correct_date)` | Upsert прогресса изучения слова + greedy-chain алгоритм "выучено" | authenticated |
| `try_consume_quota(p_user_id, p_kind, p_limit)` | Атомарный инкремент квоты (message/generation) с проверкой лимита | authenticated, service_role |
| `complete_assessment(p_answers)` | Server-side оценка теста, установка cefr_level + assessment_completed | authenticated |

Все RPC — `SECURITY DEFINER`, `SET search_path = public`, с auth guard и REVOKE/GRANT.

### Триггеры

| Триггер | Таблица | Событие | Функция |
|---|---|---|---|
| `on_auth_user_created` | `auth.users` | AFTER INSERT | `handle_new_user()` — создаёт profiles row |
| `on_auth_user_updated` | `auth.users` | BEFORE UPDATE | `handle_admin_role()` — выдаёт/отзывает роль |
| `on_auth_user_inserted` | `auth.users` | BEFORE INSERT | `handle_admin_role()` — выдаёт роль при регистрации |

### Ключевые конфиги в `app_config`

- `daily_message_limit`: `'20'`
- `xp_per_correct_answer`: `'10'`

### Каскадное удаление

Все FK используют `ON DELETE CASCADE`.

---

## Edge Functions

### `chat` (`supabase/functions/chat/index.ts`)

AI-чат с Claude. Non-streaming JSON mode.

**Flow:**
1. CORS preflight (shared `handleCors`)
2. JWT verification (shared `verifyAuth`)
3. Parse request: `{ message, context_source?, context_payload? }`
4. Input validation: message required, max 10 000 символов
5. Atomic quota: `try_consume_quota(user_id, 'message', dailyLimit)`
6. Загрузка профиля → системный промпт (имя, CEFR, уровень, XP, streak)
7. Загрузка последних 20 сообщений из `chat_messages`
8. Sanitize context_payload (truncate 500, strip control chars, escape delimiters)
9. Сохранение user message в `chat_messages`
10. Claude API call (non-streaming JSON, model из `_shared/constants.ts`)
11. Сохранение assistant message в `chat_messages`
12. JSON response с текстом и quota info

**Response (200):**
```json
{ "text": "...", "daily_limit": 20, "daily_remaining": 15 }
```

**Коды:** 400, 401, 429 (лимит), 500, 502 (Claude error)

### `generate-word-entry` (`supabase/functions/generate-word-entry/index.ts`)

Генерация структурированного WordEntry через Claude. **Admin-only.**

**Flow:**
1. CORS preflight (shared `handleCors`)
2. JWT verification (shared `verifyAuth`)
3. Admin gate: `app_metadata.role === 'admin'` → 403
4. Atomic quota: `try_consume_quota(user_id, 'generation', 10)`
5. Parse request: `{ word }`
6. Claude API call → JSON WordEntry
7. Validate: meanings array non-empty
8. Return `{ data: wordEntry }`

**Response (200):**
```json
{ "data": { "word": "...", "ipa": "...", "level": "b1", "meanings": [...], "tags": [...], "topic": "..." } }
```

**Коды:** 400, 401, 403 (not admin), 429 (лимит), 500, 502

### Shared code (`supabase/functions/_shared/`)

| Файл | Назначение |
|---|---|
| `constants.ts` | `CLAUDE_MODEL`, `CLAUDE_API_URL` |
| `cors.ts` | `corsHeaders`, `handleCors(req)` |
| `auth.ts` | `verifyAuth(req)` → `AuthResult \| Response` |
| `response.ts` | `jsonResponse(body, status)` |
| `env.ts` | `requireEnv(key)` — fail-fast |

---

## Роутинг и навигация

| Маршрут | Экран | Shell | Защита |
|---|---|---|---|
| `/login` | LoginScreen | Нет | — |
| `/register` | RegisterScreen | Нет | — |
| `/` | HomeScreen | Да | Auth required |
| `/grammar` | GrammarScreen | Да | Auth required |
| `/practice` | WordQuizHomeScreen | Да | Auth required |
| `/profile` | ProfileScreen | Да | Auth required |
| `/profile/settings` | SettingsScreen | Да | Auth required |
| `/chat` | ChatScreen | Нет | Auth required |
| `/quiz` | WordQuizScreen | Нет | Auth required |
| `/practice/add-word` | AddWordScreen | Нет | Auth required |
| `/admin` | AdminWordListScreen | Нет | Admin (UI-level, RLS enforced) |

- **Auth guard:** проверяет сессию через `authRepositoryProvider`
- **Redirect:** неавторизованные → `/login`; авторизованные на auth-маршруте → `/`
- **Shell route:** нижняя навигация (`ScaffoldWithNav`) — home, grammar, practice, profile
- **Router refresh:** `GoRouterRefreshStream(authRepository.authStateChanges())` — автоматический redirect при login/logout
- **Чат:** принимает `initialPrompt` через `state.extra`
- **Контекстный чат:** переход из grammar/practice с контекстом (`ChatContextSource`)

---

## Аутентификация

- **Провайдер:** только email/password (Supabase Auth)
- **AuthRepository:** обёртка Supabase auth API (`keepAlive: true`)
- **После регистрации:** триггер `handle_new_user()` создаёт profiles row (nickname из metadata)
- **Админ-роль:** триггер `handle_admin_role()` проверяет email в `admin_emails` при INSERT и UPDATE. JWT cache lag ~1h (роль в `app_metadata`, действует после обновления токена)
- **Assessment:** `complete_assessment` RPC оценивает тест server-side
- **Ошибки:** локализованы на русский

---

## Архитектура

### Feature-based структура

```
lib/src/
├── core/                           # Инфраструктура
│   ├── common_widgets/             # Переиспользуемые виджеты
│   ├── constants/                  # Цвета, размеры, тема
│   ├── exceptions/                 # Error logger
│   ├── local_storage/              # SharedPreferences + Drift (SQLite)
│   ├── supabase/                   # Инициализация Supabase
│   └── utils/                      # Logger, NotifierMounted mixin
├── features/                       # Фичи (domain/data/application/presentation)
│   ├── admin/                      # Админ-панель (CRUD daily_words)
│   ├── assessment/                 # Тест уровня (12 вопросов → cefr_level)
│   ├── auth/                       # Авторизация (AuthRepository)
│   ├── chat/                       # AI-чат с Claude
│   ├── grammar/                    # Грамматика
│   ├── home/                       # Главный экран (прогресс)
│   ├── profile/                    # Профиль + настройки
│   └── word_quiz/                  # Word quiz (domain/data/application/presentation)
└── routing/                        # GoRouter + GoRouterRefreshStream
```

### Слои внутри фичи

- **domain/** — модели (freezed в word_quiz, plain classes в остальных)
- **data/** — репозитории (Supabase SDK, Drift для локальных слов)
- **application/** — контроллеры (Riverpod `@riverpod` AsyncNotifier / Notifier)
- **presentation/** — экраны и виджеты

### NotifierMounted mixin

Все async-нотифаеры используют `NotifierMounted` mixin (`core/utils/notifier_mounted.dart`) для проверки `mounted` перед установкой state.

### Supabase DELETE workaround

PostgREST требует фильтр на DELETE. Для удаления всех строк владельца (с RLS): `.delete().neq('id', '')`.

### Quiz Day Timezone Logic

Дневной word quiz переключается в **02:00 Almaty time** (21:00 UTC предыдущего дня). Almaty hardcoded как UTC+5.

- **Client (Dart):** `DateTime.now().toUtc().add(Duration(hours: 3))` truncated to date
- **Server (SQL):** `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date`

### Инициализация приложения

```
main() → initSupabase() → SharedPreferences.getInstance()
       → AppDatabase (Drift) → ProviderScope(overrides: [prefs, db]) → LangualioApp
```

---

## Внешние сервисы

| Сервис | Назначение | Конфигурация |
|---|---|---|
| Supabase Auth | Аутентификация | `SUPABASE_URL`, `SUPABASE_ANON_KEY` (--dart-define) |
| Supabase Database | Хранение данных | Через Supabase SDK |
| Supabase Edge Functions | Бэкенд-логика чата и генерации | `SUPABASE_SERVICE_ROLE_KEY` (env) |
| Anthropic Claude API | AI-чат и генерация слов | `CLAUDE_API_KEY` (env в Edge Function) |
