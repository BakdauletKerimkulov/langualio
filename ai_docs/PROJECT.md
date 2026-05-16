# Langualio (WordLevel)

Мобильное приложение для изучения английского языка. Язык интерфейса — русский, учебный контент — английский.

## Стек

- **Frontend:** Flutter (Dart SDK ^3.9.2)
- **State management:** Riverpod 2.6.1 (flutter_riverpod + riverpod_annotation + riverpod_generator)
- **Навигация:** go_router 15.1.2
- **Backend:** Supabase (auth, database, Edge Functions)
- **БД:** PostgreSQL (через Supabase, миграции в `supabase/migrations/`)
- **Edge Functions:** Supabase Functions (Deno/TypeScript, `supabase/functions/`)
- **AI:** Claude Sonnet (claude-sonnet-4-20250514) через Anthropic API
- **Локальное хранилище:** SharedPreferences (обёртка `LocalStorage`)
- **Шрифт:** Nunito (Google Fonts), Material 3

## Платформы

Android, iOS, Web.

---

## Бизнес-логика и домен

### Ключевые сущности

| Сущность | Описание | Таблица в БД |
|---|---|---|
| **AppUser** | Авторизованный пользователь (id, email, name) | `profiles` (auto-create trigger) |
| **UserProgress** | Прогресс: уровень, XP, streak, дневные цели | `profiles` + `daily_goals` |
| **UserProfile** | Расширенный профиль со статистикой и ачивками | `profiles` |
| **ChatMessage** | Сообщение в чате (role, text, context) | `chat_messages` |
| **GrammarItem** | Грамматическое правило с примерами и статусом | `grammar_items` + `user_grammar_progress` |
| **Question** | Вопрос для практики (слово, варианты, правильный ответ) | `practice_questions` + `practice_attempts` |
| **DailyGoal** | Дневная цель с XP-наградой | `daily_goals` |
| **Achievement** | Достижение (title, isUnlocked) | — (пока mock) |

### Система прогресса

- **Уровни:** числовые (1, 2, 3...), не CEFR (A1–C2)
- **XP:** зарабатывается за правильные ответы (10 XP за ответ), выполнение дневных целей
- **Левелинг:** currentXp / targetXp — при достижении targetXp уровень растёт
- **Streak:** количество дней подряд, отслеживается через `last_active_date`
- **Дневные цели:** список задач на день, каждая с XP-наградой

### Система грамматики

- **Статусы:** `completed` → `unlocked` → `locked` (линейная прогрессия)
- **Прогресс:** rulesMastered / totalRules (e.g., "8/8")
- **Контент:** категория, формула, примеры с подсветкой (before | highlight | after)

### Лимиты чата

- **Дневной лимит:** 20 сообщений/день (настраивается через `app_config` таблицу)
- **Локальный кеш:** максимум 50 сообщений в SharedPreferences
- **История для контекста:** последние 20 сообщений отправляются в Claude

---

## Суpabase-схема

### Таблицы

| Таблица | Назначение | RLS |
|---|---|---|
| `profiles` | Профиль пользователя (level, xp, streak, stats) | SELECT/UPDATE: own |
| `daily_goals` | Дневные цели с XP | SELECT/INSERT/UPDATE: own |
| `grammar_items` | Контент грамматики (read-only) | SELECT: authenticated |
| `user_grammar_progress` | Прогресс по грамматике (unique: user_id + grammar_id) | SELECT/INSERT/UPDATE: own |
| `practice_questions` | Вопросы для квизов (read-only) | SELECT: authenticated |
| `practice_attempts` | Ответы пользователя | SELECT/INSERT: own |
| `chat_messages` | История чата | SELECT/INSERT: own |
| `app_config` | Конфигурация (лимиты, константы) | SELECT: authenticated (write: admin only) |
| `user_daily_usage` | Счётчик сообщений/день (unique: user_id + date) | SELECT/INSERT/UPDATE: own |

### Ключевые конфиги в `app_config`

- `daily_message_limit`: `'20'`
- `xp_per_correct_answer`: `'10'`

### Триггеры

- `handle_new_user()` — автоматически создаёт запись в `profiles` при регистрации через auth

### Каскадное удаление

Все FK используют `ON DELETE CASCADE`.

---

## Edge Functions

### `chat` (supabase/functions/chat/index.ts)

AI-чат с Claude. Полный flow:

1. Проверка Bearer-токена через Supabase Auth
2. Проверка дневного лимита (`user_daily_usage` + `app_config`)
3. Загрузка профиля пользователя для системного промпта
4. Загрузка последних 20 сообщений из `chat_messages`
5. Сборка системного промпта с контекстом пользователя (имя, уровень, XP, streak)
6. Вызов Claude API со стримингом
7. SSE-стрим ответа клиенту
8. Сохранение обоих сообщений в `chat_messages`
9. Обновление `user_daily_usage`

**Правила системного промпта:**
- Объяснения на русском, примеры на английском
- Короткие и чёткие ответы
- Подсказки вместо прямых ответов при ошибках
- Не переводит большие тексты
- Только тема изучения английского
- Адаптация сложности под уровень пользователя

**Коды ответов:** 401 (auth), 429 (лимит), 502 (API error), 500 (server error)

**Заголовки ответа:** `X-Daily-Limit`, `X-Daily-Remaining`

---

## Роутинг и навигация

| Маршрут | Экран | Защита |
|---|---|---|
| `/login` | LoginScreen | — |
| `/register` | RegisterScreen | — |
| `/` | HomeScreen | Auth required |
| `/grammar` | GrammarScreen | Auth required |
| `/practice` | PracticeScreen | Auth required |
| `/profile` | ProfileScreen | Auth required |
| `/chat` | ChatScreen | Auth required |

- **Auth guard:** проверяет `Supabase.instance.client.auth.currentSession`
- **Редирект:** авторизованные → `/`, неавторизованные → `/login`
- **Shell route:** нижняя навигация (home, grammar, practice, profile)
- **Чат:** открывается отдельно, принимает `initialPrompt` через `route.extra`
- **Контекстный чат:** можно перейти из grammar/practice с контекстом (`ChatContextSource`)

---

## Аутентификация

- **Провайдер:** только email/password (Supabase Auth)
- **Нет:** Google Sign-In, Apple Sign-In, OAuth
- **После регистрации:** автосоздание профиля через DB-триггер, редирект на home
- **Ошибки:** локализованы на русский (неверный пароль, email не подтверждён, и т.д.)

---

## Внешние сервисы

| Сервис | Назначение | Конфигурация |
|---|---|---|
| Supabase Auth | Аутентификация | `SUPABASE_URL`, `SUPABASE_ANON_KEY` (--dart-define) |
| Supabase Database | Хранение данных | Через Supabase SDK |
| Supabase Edge Functions | Бэкенд-логика чата | `SUPABASE_SERVICE_ROLE_KEY` (env) |
| Anthropic Claude API | AI-чат | `CLAUDE_API_KEY` (env в Edge Function) |

**Примечание:** в проекте есть `ClaudeApiClient` (`lib/src/core/api/claude_api_client.dart`) для прямого вызова Claude API, но основной путь — через Edge Function.

---

## Текущее состояние (MVP)

### Работает с бэкендом
- Auth (email/password, полный flow)
- Chat (Edge Function → Claude API, стриминг, лимиты, persistence)

### Только mock-данные (нет интеграции с Supabase)
- Home (UserProgress — mock)
- Grammar (GrammarItem — 3 hardcoded items)
- Practice (Question — 3 hardcoded вопроса)
- Profile (UserProfile, Achievement — mock)

### Отсутствует
- Локализация (i18n) — строки захардкожены на русском
- CI/CD — нет конфигурации
- Тесты — нет unit/widget/integration тестов
- Push-уведомления
- Onboarding flow
- Социальная авторизация
- Монетизация

---

## Архитектура

### Feature-based структура

```
lib/src/
├── core/                           # Инфраструктура
│   ├── api/claude_api_client.dart  # Прямой клиент Claude API
│   ├── storage/                    # LocalStorage + providers
│   ├── supabase/                   # Инициализация Supabase
│   └── utils/logger.dart           # Логирование
├── features/                       # Фичи (domain/data/application/presentation)
│   ├── auth/
│   ├── chat/
│   ├── grammar/
│   ├── home/
│   ├── word_quiz/
│   └── profile/
├── routing/                        # GoRouter + bottom nav
└── shared/
    ├── common_widgets/             # Переиспользуемые виджеты
    └── constants/                  # Цвета, размеры, тема
```

### Слои внутри фичи

- **domain/** — модели (plain immutable classes, без freezed)
- **data/** — репозитории (Supabase/локальное хранилище)
- **application/** — контроллеры (Riverpod StateNotifier / AsyncNotifier)
- **presentation/** — экраны и виджеты

### Known Import Conflicts

- **`LocalStorage`**: `package:supabase_flutter` exports a `LocalStorage` class that conflicts with `lib/src/core/storage/local_storage.dart`. When importing both, always use: `import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;`

### Quiz Day Timezone Logic

The daily word quiz rolls over at **02:00 Almaty time** (21:00 UTC previous day). Almaty is hardcoded as UTC+5 (no timezone package).

- **Client (Dart):** `DateTime.now().toUtc().add(Duration(hours: 3))` truncated to date — the `+3` = UTC+5 minus 2h rollover offset. See `lib/src/features/word_quiz/domain/quiz_day_util.dart`.
- **Server (SQL):** `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date`

Both must produce the same date for any given moment. If Kazakhstan changes its UTC offset, both must be updated.

### Инициализация приложения

```
main() → initSupabase() → SharedPreferences.getInstance()
       → ProviderScope(overrides: [prefs]) → LangualioApp
```