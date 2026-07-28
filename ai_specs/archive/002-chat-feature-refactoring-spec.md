# Spec: Chat Feature Refactoring

Created: 2026-05-16
Status: refined

## Goal
Переписать клиентскую часть чата с AI, чтобы она полноценно работала с серверной историей из Supabase (таблица `chat_messages`), убрать все mock/хардкод заглушки, добавить пагинацию и автоудаление старых сообщений.

## Background
Серверная часть (Edge Function `chat`) уже работает: авторизация, лимиты, вызов Claude API, стриминг, сохранение в БД. Однако клиент:
- Загружает историю из **SharedPreferences**, а не из `chat_messages` в Supabase
- Содержит **mock fallback** (`_mockResponse`), который маскирует ошибки хардкодом вместо показа реальной ошибки
- Не поддерживает пагинацию — все сообщения загружаются сразу
- Не удаляет старые сообщения

**Важно:** Клиент НИКОГДА не пишет в `chat_messages` — запись выполняет только Edge Function. Клиент только читает из таблицы для загрузки истории.

## User Flow
1. Пользователь открывает чат
2. Приложение мгновенно показывает сообщения из локального кеша (SharedPreferences)
3. Параллельно загружает последние 20 сообщений из Supabase (`chat_messages`) и обновляет UI
4. Если сервер недоступен — остаются сообщения из кеша
5. Пользователь скроллит вверх — подгружаются следующие 20 сообщений (пагинация)
6. Пользователь пишет сообщение → оно отправляется через Edge Function → ответ Claude появляется целиком
7. Edge Function сохраняет оба сообщения (user + assistant) в `chat_messages`; клиент обновляет локальный кеш
8. Сообщения старше 48 часов автоматически не отображаются (фильтр на сервере)

## Requirements
### Must Have
- [ ] `ChatRepository` загружает историю из Supabase (`chat_messages`) с пагинацией по 20 сообщений
- [ ] Fallback на SharedPreferences, если Supabase недоступен (offline / ошибка сети)
- [ ] Стратегия начальной загрузки: показать кеш сразу (sync), затем обновить с сервера (async)
- [ ] Локальный кеш (SharedPreferences) синхронизируется с серверными данными при успешной загрузке
- [ ] Убрать mock fallback (`_mockResponse`) — при ошибке показывать реальное сообщение об ошибке
- [ ] Убрать fallback на mock при `FunctionException` / `Failed host lookup` — показывать ошибку сети
- [ ] Пагинация: при скролле вверх подгружаются следующие 20 сообщений из `chat_messages`
- [ ] Сообщения старше 48 часов: фильтрация на уровне запроса (`WHERE created_at > now() - interval '48 hours'`)
- [ ] При очистке истории (`clearHistory`) — сначала удалить из `chat_messages` на сервере, только при успехе очистить локальный кеш. При ошибке — показать ошибку, не очищать локально.

### Nice to Have
- [ ] Индикатор "загрузка старых сообщений" при скролле вверх
- [ ] Плавная анимация появления подгруженных сообщений
- [ ] Показать количество оставшихся сообщений (из мета-события в SSE потоке)

## Technical Constraints

### Архитектура (по guidelines)
- Feature-first структура: `features/chat/{domain,data,application,presentation}`
- `domain/` — pure Dart модели, без Supabase импортов
- `data/` — репозиторий, единственный слой, который обращается к Supabase и SharedPreferences
- `application/` — контроллер (Riverpod `@riverpod`), управляет состоянием
- `presentation/` — виджеты, без бизнес-логики

### Доменная модель
- `ChatMessage` расширить: добавить опциональное поле `id` (String?) — uuid из БД, null для локальных сообщений до синхронизации
- Маппинг в репозитории: DB row `{id, user_id, role, text, context_source, context_payload, created_at}` → `ChatMessage(id, role, text, timestamp, context)`
- `timestamp` в домене соответствует `created_at` из БД

### Репозиторий
- `ChatRepository(LocalStorage storage, SupabaseClient client)` — оба через конструктор (DI)
- Провайдер: `@Riverpod(keepAlive: true)` — per guidelines для репозиториев
- Инъекция зависимостей: `ref.watch(localStorageProvider)` + `ref.watch(supabaseClientProvider)`
- Метод `Future<List<ChatMessage>> fetchMessages({int limit = 20, DateTime? before})` — загрузка из Supabase с курсорной пагинацией по `created_at`
- Фильтр: `created_at > now() - interval '48 hours'`
- При успешной загрузке — сохранять в SharedPreferences как кеш
- При ошибке сети — возвращать из SharedPreferences (без client-side 48h фильтра — допускаем slightly stale data offline)
- Метод `Future<void> deleteAllMessages()` — DELETE из `chat_messages` на сервере + очистка SharedPreferences только при успехе
- Метод `List<ChatMessage> loadCachedMessages()` — синхронная загрузка из SharedPreferences (для мгновенного отображения)
- **Клиент НЕ записывает в `chat_messages`** — запись только через Edge Function

### Провайдер / Контроллер
- `ChatNotifier` (`@riverpod`, auto-dispose) — остаётся синхронным `Notifier` (не AsyncNotifier)
- `build()` возвращает `ChatState` синхронно: загружает кеш через `loadCachedMessages()`, затем запускает async refresh с сервера (обновляет state по завершении)
- Это позволяет избежать миграции всех виджетов на `AsyncValue<ChatState>`
- `ChatState` расширить: `hasMore` (есть ли ещё сообщения для пагинации), `isLoadingMore` (загрузка при скролле)
- `loadMore()` — подгрузка следующей страницы, вставка в начало списка
- Убрать `_mockResponse` и связанный fallback

### Пагинация (presentation)
- Триггер: `_scrollController.position.pixels <= _scrollController.position.minScrollExtent + 200` (200px threshold)
- `ListView.separated` отображает сообщения хронологически (top = old, bottom = new) — скролл вверх = к `minScrollExtent`
- При триггере вызывать `ref.read(chatNotifierProvider.notifier).loadMore()`
- Не вызывать повторно пока `isLoadingMore == true` или `hasMore == false`

### Supabase
- Таблица `chat_messages` уже существует с RLS (SELECT/INSERT: own)
- Нужна RLS policy для DELETE: `auth.uid() = user_id` (для clearHistory)
- Миграция: `supabase migration new add_chat_delete_policy_and_index`

```sql
-- Delete policy for clearHistory
create policy "Users can delete own messages"
  on public.chat_messages for delete using (auth.uid() = user_id);

-- Index for efficient paginated queries
create index idx_chat_messages_user_created
  on public.chat_messages(user_id, created_at desc);
```

- Опционально: серверная cron-задача или DB trigger для физического удаления сообщений > 48ч

### Пакеты
- `supabase_flutter` — уже в проекте
- `shared_preferences` — уже в проекте (через `LocalStorage`)
- Новых пакетов не нужно

## Edge Cases
- **Нет интернета при первом открытии:** Загрузить из SharedPreferences. Если кеш пуст — показать empty state с suggested prompts
- **Нет интернета при отправке:** Показать ошибку "Проверь интернет", не добавлять mock-ответ
- **SharedPreferences пуст и сервер недоступен:** Empty state, suggested prompts
- **Сообщений меньше 20:** `hasMore = false`, не показывать индикатор подгрузки
- **Все сообщения старше 48ч:** Чат показывает empty state (как новый чат)
- **Edge Function вернула 429 (лимит):** Показать баннер лимита (уже реализовано)
- **Edge Function вернула 502 (Claude API error):** Показать "Ошибка AI-сервиса. Попробуй позже."
- **Гонка состояний:** Пользователь отправляет сообщение пока грузится пагинация — новое сообщение добавляется в конец, пагинация продолжается независимо
- **clearHistory при отсутствии сети:** Показать ошибку, не очищать локальный кеш (messages reappear on next online load otherwise)
- **Дубли timestamp при пагинации:** Крайне маловероятно (microsecond precision + sequential INSERT), но если возникнет — допускаем дубли, не ломает UX

## Out of Scope
- Реальный SSE-стриминг в UI (текст по буквам) — не требуется
- Несколько чатов/сессий — один непрерывный чат
- Смена AI-модели (остаётся Claude Sonnet)
- Изменения системного промпта или поведения Edge Function
- Offline отправка сообщений (очередь) — при отсутствии сети просто показываем ошибку
- Клиентская запись в `chat_messages` — только Edge Function пишет в таблицу

## Definition of Done
- [ ] Все Must Have requirements реализованы
- [ ] История загружается из Supabase при наличии сети
- [ ] Fallback на SharedPreferences работает при отсутствии сети
- [ ] Mock-заглушки полностью удалены
- [ ] Пагинация при скролле вверх работает
- [ ] Сообщения старше 48ч не отображаются
- [ ] DELETE policy добавлена в миграцию
- [ ] Индекс `(user_id, created_at DESC)` добавлен в миграцию
- [ ] `ChatMessage` модель расширена полем `id`
- [ ] `ChatRepository` использует `@Riverpod(keepAlive: true)`
- [ ] Edge cases обработаны
- [ ] Ручной QA пройден