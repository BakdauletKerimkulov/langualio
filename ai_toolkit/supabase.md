# Supabase Guidelines

Universal Supabase patterns (Postgres + RLS + RPC + Edge Functions) for this project. Project-specific tables, columns, and functions belong in `ai_docs/`. TypeScript Edge Function conventions live in `edge-functions.md`.

---

## Mandatory Table Columns

**Every table must contain these columns:**

| Column | Type | Rule |
|--------|------|------|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` |
| `created_at` | `timestamptz` | `DEFAULT now()`. Set once. Never updated. |
| `updated_at` | `timestamptz` | `DEFAULT now()`. Bumped on every write (trigger). |

```sql
CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
  -- ... other columns
);

-- Reusable trigger to bump updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

CREATE TRIGGER orders_set_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

**Why server-side defaults?** Client clocks are unreliable (timezone, skew, manipulation). `now()` in Postgres guarantees consistent ordering and conflict resolution. Never send `created_at`/`updated_at` from the client.

Naming: tables and columns `snake_case`, tables plural (`orders`, `user_daily_usage`).

---

## Row Level Security (RLS)

RLS is the Supabase equivalent of Firestore Security Rules. **Deny by default:**

```sql
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
-- No policy = no access. Only add policies for what's needed.
```

### Owner-based access

```sql
CREATE POLICY "users read own orders"
  ON public.orders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users insert own orders"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### Server-authoritative fields

Columns that only the backend may modify (balances, counters, statuses, prices): do **not** grant client `UPDATE` on them. Either:

- Route all writes through an RPC / Edge Function (service role bypasses RLS), and give the client no `UPDATE` policy at all; or
- Restrict updatable columns via `GRANT`:

```sql
REVOKE UPDATE ON public.users FROM authenticated;
GRANT UPDATE (display_name, avatar_url) ON public.users TO authenticated;
```

### Immutable / audit data

For logs and history tables: `INSERT` policy only — no `UPDATE`, no `DELETE`.

### General rules

- Never trust client-sent data for prices, scores, quotas, permissions.
- No client-side `DELETE` for critical data (orders, payments, progress).
- Every user-facing query must be bounded: `.limit(n)` or scoped by `user_id`.
- Add indexes for every column used in policies and frequent filters (`user_id`, `date`).

---

## RPC Functions (Postgres)

### Security — every `SECURITY DEFINER` function must include all three:

1. **`SET search_path = public`** — prevents schema injection attacks.
2. **Auth guard** at the top of any function touching user-scoped data:

```sql
IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'Not authenticated';
END IF;
```

3. **REVOKE/GRANT** — restrict execution to `authenticated` only:

```sql
REVOKE EXECUTE ON FUNCTION public.my_function(...) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.my_function(...) TO authenticated;
```

Prefer `SECURITY INVOKER` (default) for read-only functions that don't need to bypass RLS. Use `SECURITY DEFINER` only when elevated privileges are required (cross-table writes under RLS).

### Atomicity — RPC is the transaction

A Postgres function body runs in a single transaction. Any multi-table write that must succeed or fail together belongs in one RPC, not in sequential client/Edge Function awaits:

```sql
CREATE OR REPLACE FUNCTION public.complete_review(p_word_id uuid, p_quality int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  UPDATE user_words SET ... WHERE id = p_word_id AND user_id = auth.uid();
  INSERT INTO review_log (...) VALUES (...);
  UPDATE user_stats SET reviews_count = reviews_count + 1 WHERE user_id = auth.uid();
END $$;
```

---

## Race Condition Prevention

### Problem: read-modify-write from the client

Two concurrent requests read `quantity = 1`, both decrement, both succeed → oversell. Never do check-then-write from Flutter or across multiple Edge Function awaits.

### Solutions (in order of preference)

1. **Atomic UPDATE with condition** — check and write in one statement:

```sql
UPDATE offers
SET quantity_remaining = quantity_remaining - 1
WHERE id = p_offer_id AND quantity_remaining >= 1
RETURNING id; -- no row returned = not enough stock → raise
```

2. **`FOR UPDATE` row lock** inside an RPC when you must read before writing:

```sql
SELECT quantity_remaining INTO v_remaining
FROM offers WHERE id = p_offer_id
FOR UPDATE; -- blocks concurrent readers-for-update until commit
```

3. **Unique constraints** as the last line of defense against duplicates (see idempotency).

| Scenario | Approach |
|----------|----------|
| Simple counter increment | Atomic `UPDATE ... SET x = x + 1` / upsert |
| Check value before write (don't go below 0) | Conditional `UPDATE ... WHERE` or `FOR UPDATE` in RPC |
| Multi-table consistent write | Single RPC (one transaction) |
| Status transition with guard | `UPDATE ... WHERE status = 'expected'`, check row count |

---

## Idempotency

Retries, slow networks, and double-taps cause duplicate calls. Every state-changing operation needs a strategy — document it in a comment.

### Strategy 1: unique constraint + upsert (preferred)

```sql
-- One usage row per user per day, no duplicates possible
ALTER TABLE user_daily_usage ADD CONSTRAINT user_date_unique UNIQUE (user_id, date);
```

```ts
await supabase.from("user_daily_usage").upsert(
  { user_id: user.id, date: today, generation_count: n + 1 },
  { onConflict: "user_id,date" },
);
```

### Strategy 2: deterministic ID / natural key

Use a predictable key (`{user_id}_{word_id}`, `{item_id}_{date}`) so retries overwrite instead of duplicating.

### Strategy 3: status guard

```sql
UPDATE orders SET status = 'picked_up'
WHERE id = p_id AND status = 'ready'; -- already picked_up → 0 rows, no-op
```

---

## Edge Functions

Full conventions in `edge-functions.md`. Key boundaries:

- Edge Functions are for: external APIs (Claude, payments), logic that must not ship in the client, orchestration.
- Pure DB logic (multi-table writes, counters, guarded transitions) belongs in RPC — a single transaction beats N awaits.
- Service role key (`SUPABASE_SERVICE_ROLE_KEY`) bypasses RLS: use only server-side, never expose, and re-verify the JWT (`supabase.auth.getUser(token)`) before acting on behalf of a user.

---

## Supabase Auth (Flutter)

### Auth state stream (Riverpod)

```dart
@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}
```

- Read the current user via `Supabase.instance.client.auth.currentUser`, but drive UI from the stream.
- Never store the user's role/permissions client-side as the source of truth — enforce with RLS.

---

## Roles & Admin

- Roles live in `auth.users.raw_app_meta_data` (**app_metadata**) — writable only server-side. Never in `user_metadata`/`raw_user_meta_data`: the client can edit those freely, so any security decision based on them is broken.
- Check in RLS via JWT claim (no table lookup, fast): `(auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'`.
- JWT is a cache: after granting/revoking a role the old token stays valid until refresh (up to ~1h). Revocation is not instant — for instant lockout, additionally check a table. Grant flow requires re-login/refresh; document this in the feature.
- Whitelist/role tables (`admin_emails`, `user_roles`): RLS enabled with **no client policies at all** — written only by migrations or service role. Never mutate roles by hand in Studio (bypasses whitelist logic and history).
- Admin triggers on `auth.users` must fire on both INSERT and UPDATE if the role should apply at first signup.
- Admin-only Edge Functions must verify the role explicitly after `getUser(token)` and return 403 — the service-role client bypasses RLS, so RLS will not protect you there.
- Client-side `isAdmin` state is UX (hide buttons); enforcement is always RLS/RPC/403.

---

## Migrations

- Every schema change is a migration: `supabase migration new <name>`. Never edit the DB by hand in Studio for anything that must be reproducible.
- Migrations are append-only history — never rewrite an applied migration; write a new one.
- Prefer backward-compatible changes (add nullable column → backfill → tighten). Destructive changes require an explicit, documented decision.
- Verify locally with `supabase db reset` (replays all migrations from scratch) before `supabase db push`.

---

## Local Development

```bash
supabase start          # local stack (Docker)
supabase db reset       # apply all migrations from scratch
supabase functions serve # local Edge Functions
supabase stop
```

Test RLS policies locally: run queries as `anon`/`authenticated` (Studio role switcher or `set local role`) — not just as `postgres`, which bypasses RLS.

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---------|-----------------|
| Table without RLS enabled | `ENABLE ROW LEVEL SECURITY` on every table, deny by default |
| Writing server-authoritative fields from client | No UPDATE policy / column GRANT; write via RPC or Edge Function |
| Client-side `DateTime.now()` for timestamps | `DEFAULT now()` + `set_updated_at` trigger |
| Read-modify-write across awaits | Conditional `UPDATE` or `FOR UPDATE` inside one RPC |
| Multi-table writes via sequential client calls | Single RPC = single transaction |
| Missing idempotency strategy | Unique constraint / deterministic key / status guard |
| `SECURITY DEFINER` without `search_path` | Always `SET search_path = public` |
| RPC executable by `anon` | `REVOKE ... FROM anon` + `GRANT ... TO authenticated` |
| Service role key in client code | Server-side only (Edge Function secrets) |
| Unbounded queries | `.limit()` or scope by `user_id` |
| Editing schema in Studio by hand | Migrations only |
| Testing RLS as `postgres` role | Test as `anon`/`authenticated` |

---

## Repository Pattern (Supabase client)

Supabase-specific form of the repository described in `core/architecture.md`. Repositories live in `data/` and are the only layer that touches the Supabase client. They accept and return **domain models**, never raw rows or DTOs.

```dart
// data/orders_repository.dart
class OrdersRepository {
  const OrdersRepository({required this.uid, required this.client});

  final String uid;
  final SupabaseClient client;

  /// Watch active orders for current user (real-time stream)
  Stream<List<Order>> watchActiveOrders() {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((row) => OrderDto.fromJson(row).toDomain())
            .toList());
  }

  /// Create order via RPC (single transaction, not sequential client writes)
  Future<Order> createOrder({
    required String offerId,
    required int quantity,
  }) async {
    final result = await client.rpc<Map<String, dynamic>>(
      'create_order',
      params: {'p_offer_id': offerId, 'p_quantity': quantity},
    );
    return OrderDto.fromJson(result).toDomain();
  }
}
```

**Rules:**
- Constructor injection for the Supabase client (testable via mocks)
- Stream methods for real-time data (`watchX`), Future methods for one-shot reads (`fetchX`) and writes
- All row → domain mapping happens inside the repository; keep the mapper a pure static function so it is testable without a client (see `core/testing.md`)
- Never expose raw rows (`Map<String, dynamic>`, `PostgrestResponse`) to the application layer
- Multi-table writes go through an RPC — see "Atomicity — RPC is the transaction" above

---

## Supabase Error Mapping

Map Supabase errors to the typed `AppException` hierarchy (`core/architecture.md` → Error Handling) in the data layer — nothing above `data/` should see a `PostgrestException` or an `AuthException`:

```dart
class SupabaseErrorMapper {
  static AppException map(Object error) => switch (error) {
    AuthException(:final message) => ValidationException(message),
    PostgrestException(code: 'PGRST116') =>
      const NotFoundException('Not found'),
    PostgrestException(:final code, :final message) =>
      ServerException('$code: $message'),
    _ => NetworkException('Unknown error: $error'),
  };
}
```

RLS denials and failed guard clauses surface as `PostgrestException` — map them to a user-facing message, never leak the raw Postgres error text to the UI.

---

## App Bootstrap (Supabase)

Supabase-specific part of the bootstrap sequence in `core/architecture.md` → App Bootstrap:

```dart
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Supabase init (URL + anon key from compile-time env — see envied in core/architecture.md)
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

    // 2. Local stack config (if enabled) — point URL at the local `supabase start` instance

    // 3. Create ProviderContainer
    final container = ProviderContainer(observers: [...]);

    // 4. Run app with UncontrolledProviderScope
    runApp(UncontrolledProviderScope(container: container, child: const App()));
  }, (error, stack) {
    // Top-level error handler
  });
}
```

The anon key is public by design — it is safe in the client only because RLS is enabled on every table. The service role key never leaves the server (Edge Function secrets).
