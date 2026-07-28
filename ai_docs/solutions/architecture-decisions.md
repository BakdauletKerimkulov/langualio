# Architecture Decisions (extracted from ai_specs)

Ключевые решения и паттерны, принятые при разработке проекта. Источник: спецификации 001–013.

---

## 1. Timezone & Day Boundary (spec 001)

- **Rollover в 02:00 Almaty (UTC+5)** — новый "учебный день" начинается в 2 ночи
- Server-side: `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date`
- Client-side: hardcoded UTC+5 offset (не зависит от системного timezone устройства)
- Это единый подход для quiz progress, daily usage limits, streak counting

## 2. Offline-First Strategy (specs 001, 002, 008)

- LocalStorage/Drift cache + opportunistic Supabase sync
- **Нет connectivity listener** — проще, меньше багов
- При network error показываем cached data, не пустой экран
- Asset JSON (~2000 B1 words) как base pool — quiz работает без сети с первого запуска
- `WordSource` enum (`asset` | `user` | `server`) для tracking происхождения слова

## 3. Spaced Repetition Algorithm (spec 001)

- **Mastery threshold:** 3 correct answers on non-consecutive days
- Gap-based chaining: 1–3 day gaps between correct dates, chain length ≥ 3
- Server-side JSONB `dates_correct` array в `word_learning_progress`
- `upsert_word_learning_progress()` RPC — atomic merge prevents multi-device conflicts
- Progress tracking на уровне word (не meaning) — проще mastery logic

## 4. Multi-Meaning Word Model (spec 005)

- `meanings` как JSONB array в `daily_words` table
- `WordMeaning` model: POS, translation, definitions, examples — self-contained
- `QuizSession.selectedMeaningIndexes` — one random meaning per word per session
- Convenience getters: `primaryTranslation`, `primaryPartOfSpeech` для fallback UI
- Distractor pool uses primary meaning of other words

## 5. Chat Architecture (specs 002, 010, 013)

- **JSON mode (не SSE streaming):** `supabase.functions.invoke()` не поддерживает SSE
- Response format: `{ text, daily_limit, daily_remaining }`
- Dual-layer loading: sync cache (instant UI) + async Supabase refresh (background)
- Pagination: timestamp-based cursor via `created_at DESC` index
- Rate limiting: 10 messages/day via `user_daily_usage.message_count`
- Edge Function split: `index.ts` (orchestrator ≤200 lines) + `prompt.ts` (pure logic)
- CEFR-aware system prompt: level from `profiles` table, fallback "beginner"

## 6. Context & Input Sanitization (spec 010)

- Max 10,000 chars per message (server-side check)
- `context_payload` truncated to 500 chars
- Strip control chars, escape prompt delimiters — prevents prompt injection
- Env var guards at Edge Function startup (CLAUDE_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

## 7. Admin Role System (spec 004)

- DB trigger `on_auth_user_updated` checks `admin_emails` table
- Sets `raw_app_meta_data.role = 'admin'` — survives session expiry
- Client reads role from JWT claims (no extra API call)
- Duplicate word detection: case-insensitive check before insert

## 8. Word Entry Lifecycle (specs 004, 005, 008)

- Statuses: `draft → published → archived` (soft-delete, no data loss)
- RLS filters by status: quiz only sees `published`
- `created_by` nullable FK to `auth.users` for accountability
- Asset words: `createdAt` nullable (no timestamp for bundled data)
- Drift migration strategy: drop/recreate cache tables on schema change (safe — it's a cache)

## 9. Registration & Onboarding (spec 003)

- `name` → `nickname` (shorter, collision-resistant for future multiplayer)
- 12-question CEFR assessment after registration
- GoRouter `refreshListenable` + `OnboardingStateProvider` (keepAlive)
- Grandfather existing users: `assessment_completed = true` in migration
- CEFR level flows into chat system prompt

## 10. Local Word Pool Architecture (spec 009)

- `WordPoolProvider`: functional auto-dispose provider merges asset + Drift words
- Dedup by word (case-insensitive, user version wins)
- `UserWordRepository` wraps Drift with UUID generation
- Shared `WordGenerationService` for admin panel + user add-word flow
- Rate limit: 10 generations/day via `user_daily_usage.generation_count`
- User words stay local-only (no server sync — pragmatic for MVP)

## 11. Code Organization Rules (spec 007)

- File size limit: ≤300 lines
- No private `Widget _buildX()` methods — extract to separate widget classes
- `.hardcoded` extension on all UI strings (future i18n)
- `AppLogger` instead of `print()`
- AsyncNotifier + `AsyncValue.when()` for all data screens
- Repository pattern: constructor injection of SupabaseClient, return domain models

## 12. Database Patterns

- **Triggers:** `handle_new_user()` creates profile; `on_auth_user_updated` manages admin
- **JSONB for structured data:** meanings array, dates_correct array
- **RLS per table:** SELECT/INSERT/UPDATE/DELETE scoped to `auth.uid()`
- **Indexes on query paths:** `(user_id, created_at DESC)`, `(user_id, word_id)`
- **`user_daily_usage` table:** unified rate limiting (messages, generations)

---

## Known Deferred Work

1. **Real SSE streaming for chat** — requires `http` package `Client.send()` with `StreamedResponse`
2. **Unique nickname constraint** — currently allows duplicates
3. **Server sync for user words** — local-only in Drift (future feature)
4. **Achievements system** — listed as Nice-to-Have, not implemented
5. **`.hardcoded` sweep** — ~24 files still need annotation (spec 007 Phase 7)
