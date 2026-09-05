# Functional requirements
- 4-pages IOS/Android app with flutter
- main floating button in home page to chat with AI agent

# Non-functional-requirements
- Proper separation of concerns (suitable folder structure like features, shared, core).
- Prefer small, composable widgets.
- Prefer flex values over hardcoded sizes for responsive UI.
- Use log from dart:developer for logging instead of print or debugPrint.
- Riverpod with code generation (`@riverpod` annotations) as the ONLY state management and DI approach. No manual Provider/StateNotifierProvider declarations.

# AI Agent Requirements

## Role & Persona
- AI выступает как персональный English-репетитор (friendly, encouraging tone)
- Адаптирует сложность ответов под уровень пользователя (beginner → advanced)
- Отвечает на русском с объяснениями, примеры даёт на английском

## Core Capabilities

### 1. Conversational Practice
- Свободный диалог на английском с исправлением ошибок
- Объяснение ошибок: почему неправильно + правильный вариант
- Ролевые сценарии (кафе, собеседование, путешествие)

### 2. Grammar Help (связь с Grammar Screen)
- Объяснение грамматических правил из списка по запросу
- Генерация дополнительных примеров к правилам
- Ответы на вопросы типа "почему тут Present Perfect, а не Past Simple?"

### 3. Vocabulary Help (связь с Practice Screen)
- Объяснение значений, синонимов, контекста употребления слов
- Примеры использования слова в предложениях
- Помощь с запоминанием (ассоциации, мнемоники)

### 4. Progress-Aware Context (связь с Home/Profile)
- AI знает текущий уровень пользователя, streak, изученные слова
- Подстраивает сложность под прогресс
- Может предложить "давай повторим слова, которые ты недавно учил"

## Behaviour Constraints
- Не переводит большие тексты целиком — учит разбирать самостоятельно
- При ошибке сначала даёт подсказку, а не сразу ответ
- Ограничение длины ответа: короткие, понятные объяснения (не стена текста)
- Поддерживает только тематику изучения английского (не general-purpose бот)

## UX Integration
- Floating Action Button на Home Screen открывает чат
- Из Grammar/Practice экранов можно отправить контекст в чат
  (например: "Объясни это правило подробнее" или "Почему тут не подходит X?")
- Быстрые подсказки (suggested prompts) при пустом чате:
  - "Давай попрактикуем диалог"
  - "Объясни Present Perfect"
  - "Помоги с произношением слова..."

## Technical
- API: Claude API через Supabase Edge Function (серверный прокси)
- Streaming ответов для UX (текст появляется постепенно)
- Хранение истории чата в Supabase (chat_messages таблица)
- System prompt строится на сервере с данными профиля пользователя
- Настраиваемый дневной лимит AI-сообщений (app_config таблица)

# Backend Requirements

## Stack
- Supabase (PostgreSQL + Auth + Edge Functions + RLS)
- Email/password аутентификация

## Authentication
- Email + password регистрация и вход
- Профиль создаётся автоматически при регистрации (trigger)
- Redirect на login если не авторизован

## Database Tables
- `profiles` — данные пользователя (level, xp, streak, stats)
- `daily_goals` — ежедневные цели с XP
- `grammar_items` — грамматические правила (контент, read-only для юзеров)
- `user_grammar_progress` — прогресс пользователя по грамматике
- `practice_questions` — словарные вопросы (контент, read-only)
- `practice_attempts` — попытки ответов пользователя
- `chat_messages` — история чата с AI
- `app_config` — конфигурация приложения (лимиты, XP за ответ)
- `user_daily_usage` — трекинг дневного использования AI

## Security
- Row Level Security (RLS) на всех таблицах
- Пользователь видит/редактирует только свои данные
- Контент-таблицы (grammar_items, practice_questions, app_config) — read-only для юзеров
- Claude API ключ хранится ТОЛЬКО на сервере (Edge Function secrets)

## Edge Function: chat proxy
- Проверяет JWT токен
- Проверяет дневной лимит сообщений
- Строит system prompt с данными профиля из БД
- Проксирует запрос к Claude API со стримингом
- Сохраняет сообщения в chat_messages
- Возвращает оставшийся лимит в response headers

## AI Content Generation
- Грамматические правила и словарные вопросы генерируются AI
- Хранятся в БД как обычный контент
- Могут быть дополнены вручную через Supabase dashboard 