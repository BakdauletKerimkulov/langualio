# PLAN.md

Implementation plan for Langualio — English learning app with AI tutor.

---

## State Management Rules (Riverpod with code generation)

### Packages
- `flutter_riverpod` + `riverpod_annotation` — runtime
- `riverpod_generator` + `build_runner` — code generation
- `riverpod_lint` — lint rules

### Rules

1. **Всегда использовать `@riverpod` аннотации** — НЕ писать провайдеры вручную (`Provider`, `StateNotifierProvider` и т.д.). Вместо этого:
   ```dart
   @riverpod
   class MyNotifier extends _$MyNotifier {
     @override
     MyState build() => const MyState();
   }
   ```

2. **Генерация обязательна** — каждый файл с `@riverpod` должен иметь `part '*.g.dart'`. Запуск:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **DI через ref** — все зависимости (Supabase client, repositories, storage) инжектируются через `ref.watch()` / `ref.read()` внутри провайдеров. Никаких синглтонов или сервис-локаторов.

4. **Типы провайдеров:**
   - `@riverpod` функция — для простых значений, вычислений, DI (заменяет `Provider`)
   - `@riverpod` класс — для мутабельного состояния (заменяет `StateNotifier`, `Notifier`)
   - `@Riverpod(keepAlive: true)` — для сервисов, которые должны жить всё время (Supabase client, storage)

5. **Файловая структура провайдера:**
   ```
   features/chat/
   ├── application/
   │   ├── chat_provider.dart      # @riverpod class + state
   │   └── chat_provider.g.dart    # generated
   ```

6. **Экраны используют `ConsumerWidget` или `ConsumerStatefulWidget`** — никогда `StatefulWidget` для состояния, которое можно вынести в провайдер.

### Миграция текущих провайдеров
- [ ] Мигрировать `authProvider` → `@riverpod class AuthNotifier`
- [ ] Мигрировать `chatProvider` → `@riverpod class ChatNotifier`
- [ ] Мигрировать `practiceProvider` → `@riverpod class PracticeNotifier`
- [ ] Мигрировать `userProgressProvider` → `@riverpod`
- [ ] Мигрировать `grammarItemsProvider` → `@riverpod`
- [ ] Мигрировать `goRouterProvider` → `@riverpod`
- [ ] Мигрировать `supabaseClientProvider` → `@Riverpod(keepAlive: true)`
- [ ] Мигрировать `localStorageProvider` / `sharedPreferencesProvider` → `@Riverpod(keepAlive: true)`
- [ ] Мигрировать `chatRepositoryProvider` → `@riverpod`
- [ ] Запустить `dart run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze` — 0 ошибок

---

## Phase 1: Project Foundation — DONE

### 1.1 Restructure folder layout
- [x] Create `lib/src/core/` for app-wide services (logging, API client, local storage)
- [x] Create `lib/src/shared/` and move `common_widgets/` and `constants/` into it
- [x] Update all imports across the project
- [x] Add `lib/src/core/utils/logger.dart` — wrapper around `dart:developer` `log()`

### 1.2 Define data models
- [x] `lib/src/features/home/domain/user_progress.dart` — level, xp, streak, daily goals
- [x] `lib/src/features/grammar/domain/grammar_item.dart` — extract from grammar_card.dart
- [x] `lib/src/features/practice/domain/question.dart` — extract from practice_screen.dart
- [x] `lib/src/features/profile/domain/user_profile.dart` — name, level, title, stats, achievements
- [x] `lib/src/features/chat/domain/chat_message.dart` — role, text, timestamp, context

### 1.3 Activate Riverpod state management
- [x] Create providers (home, grammar, practice)
- [x] Migrate PracticeScreen to ConsumerWidget + StateNotifier
- [x] Migrate HomeScreen to ConsumerStatefulWidget with userProgressProvider

---

## Phase 2: AI Chat UI — DONE

### 2.1 Chat screen layout
- [x] `lib/src/features/chat/presentation/chat_screen.dart` — full chat screen
- [x] Add `/chat` route to GoRouter (full-screen, outside ShellRoute)

### 2.2 Chat message bubbles
- [x] `message_bubble.dart` — user (right, primary) / assistant (left, surface) bubbles
- [x] `typing_indicator.dart` — animated dots while AI responds

### 2.3 Empty chat state with suggested prompts
- [x] `suggested_prompts.dart` — 3 tappable prompt cards

### 2.4 Streaming response UI
- [x] Disable send button while response in progress
- [x] Auto-scroll to bottom on new content
- [ ] Real streaming (currently mock delay — needs Claude API in Phase 5)

### 2.5 FAB on Home Screen
- [x] FloatingActionButton in ScaffoldWithNav (home route only)
- [x] Navigates to `/chat` via GoRouter

---

## Phase 3: Cross-screen chat integration — DONE

- [x] "Ask AI" button on GrammarCard expanded body (next to Practice)
- [x] "Ask AI" button on ResultOverlay (practice results)
- [x] Context passed via GoRouter `extra` parameter as initial prompt
- [x] ChatScreen accepts `initialPrompt` and auto-sends it

---

## Phase 4: Data & Storage Layer — DONE

### 4.1 Local storage setup
- [x] Added `shared_preferences` dependency
- [x] `lib/src/core/storage/local_storage.dart` — abstraction with JSON support
- [x] `lib/src/core/storage/storage_provider.dart` — Riverpod providers
- [x] SharedPreferences initialized in main.dart via ProviderScope override
- [x] Chat history stored locally (last 50 messages)

### 4.2 Repository pattern
- [x] `lib/src/features/chat/data/chat_repository.dart` — save/load/clear chat history
- [ ] `lib/src/features/home/data/progress_repository.dart` — pending (uses mock data)
- [ ] `lib/src/features/grammar/data/grammar_repository.dart` — pending (uses mock data)
- [ ] `lib/src/features/practice/data/practice_repository.dart` — pending (uses mock data)

---

## Phase 5: AI Agent Integration — DONE

### 5.1 Claude API client
- [x] Added `http` dependency
- [x] `lib/src/core/api/claude_api_client.dart` — streaming SSE support
- [x] API key via `--dart-define=CLAUDE_API_KEY=sk-...`

### 5.2 System prompt construction
- [x] `lib/src/features/chat/data/system_prompt_builder.dart`
- [x] AI persona + user level/XP/streak + behaviour constraints + screen context

### 5.3 Chat provider (Riverpod)
- [x] `lib/src/features/chat/application/chat_provider.dart`
- [x] StateNotifier with streaming, persistence, mock fallback

### 5.4 Error handling
- [x] Error banner in chat UI with retry button
- [x] Rate limit detection (429)
- [x] Auth error detection (401)
- [x] Network error fallback message

---

## Phase 6: Polish & Non-functional Requirements — DONE

### 6.1 Logging
- [x] No print/debugPrint in codebase — `log()` from `dart:developer` used via `core/utils/logger.dart`
- [x] Logging in API client and chat provider

### Remaining (future work)
- [ ] Responsive UI audit: test on different screen sizes
- [ ] Widget decomposition audit

---

## Phase 7: Supabase Backend — DONE

### 7.1 Setup
- [x] Added `supabase_flutter` dependency
- [x] `lib/src/core/supabase/supabase_client.dart` — init + provider
- [x] Supabase URL/anon key via `--dart-define`

### 7.2 Auth feature
- [x] `lib/src/features/auth/` — domain, application, presentation
- [x] Email/password login & register screens
- [x] `authProvider` (StateNotifier) with error handling
- [x] Auth redirect guard in GoRouter
- [x] Russian error messages

### 7.3 Database schema
- [x] `supabase/migrations/001_initial_schema.sql` — 9 tables with RLS
- [x] Auto-create profile on signup (trigger)
- [x] `app_config` table with `daily_message_limit` (default: 20)
- [x] `user_daily_usage` table for tracking
- [x] Seed data for grammar items and practice questions

### 7.4 Edge Function
- [x] `supabase/functions/chat/index.ts` — Claude API proxy
- [x] JWT verification, daily limit check, system prompt from DB
- [x] Streaming SSE passthrough
- [x] Saves messages + increments usage
- [x] Returns X-Daily-Limit / X-Daily-Remaining headers

### 7.5 Chat integration
- [x] Updated `chatProvider` to use Supabase Edge Function
- [x] Daily limit counter in chat AppBar
- [x] Limit reached banner + disabled input
- [x] Mock fallback when Edge Function unavailable

### Remaining (backend)
- [ ] Connect home/grammar/practice screens to Supabase repositories
- [ ] Real-time profile sync
- [ ] Streak auto-calculation based on `last_active_date`
