# Firebase Guidelines

Universal Firebase patterns for all Flutter projects. Project-specific collections, fields, regions, and functions belong in `ai_docs/FIRESTORE_SCHEMA.md` and `ai_docs/CLOUD_FUNCTIONS.md`.

---

## Region Configuration

- Set region in a project-level constant, never hardcode in individual files
- Always use `FirebaseFunctions.instanceFor(region: kCloudFunctionsRegion)` in Flutter
- Auth triggers (`beforeCreate`, `beforeSignIn`) require `us-central1` — this is a Firebase platform constraint, not a choice

```dart
// constants.dart
const kCloudFunctionsRegion = 'asia-south1'; // defined per project in ai_docs

// usage
final functions = FirebaseFunctions.instanceFor(region: kCloudFunctionsRegion);
```

```typescript
// functions/src/index.ts
import { setGlobalOptions } from 'firebase-functions/v2';
setGlobalOptions({ region: 'asia-south1' }); // region from ai_docs
```

---

## Mandatory Document Fields

**Every Firestore document must contain these fields:**

| Field | Type | Rule |
|-------|------|------|
| `id` | `string` | Same as document ID. Store explicitly for client convenience. |
| `createdAt` | `Timestamp` | Set once on creation. Never updated. Server timestamp only. |
| `updatedAt` | `Timestamp` | Updated on every write. Server timestamp only. |

```typescript
// Creating a document
const docRef = db.collection('orders').doc();
await docRef.set({
  id: docRef.id,                              // explicit ID field
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
  // ... other fields
});

// Updating a document — always bump updatedAt
await docRef.update({
  status: 'ready',
  updatedAt: FieldValue.serverTimestamp(),
});
```

```dart
// Dart model — always include these three
class Order {
  const Order({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    // ...
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Why store `id` inside the document?**
- Firestore queries return documents, but the doc ID is metadata — not part of `data()`
- Storing `id` explicitly means `fromJson` works without special handling
- Client code can pass the model around without carrying a separate `DocumentReference`

**Why server timestamps?**
- `DateTime.now()` from client is unreliable (wrong timezone, clock skew, manipulation)
- `FieldValue.serverTimestamp()` guarantees consistency across all clients
- Enables reliable ordering and conflict resolution

---

## Firestore Rules Patterns

### Owner-based access

```firestore
function isOwner(userId) {
  return request.auth != null && request.auth.uid == userId;
}

match /users/{userId} {
  allow read, write: if isOwner(userId);
}
```

### Server-authoritative field guard

Protect fields that only Cloud Functions should modify:

```firestore
function serverFieldsUnchanged(protectedFields) {
  return !request.resource.data.diff(resource.data)
    .affectedKeys().hasAny(protectedFields);
}

// Client can update profile but not coins/level
match /users/{userId} {
  allow update: if isOwner(userId)
    && serverFieldsUnchanged(['coins', 'exp', 'level']);
}
```

### Field-level update validation

Restrict which fields a client can modify:

```firestore
allow update: if isOwner(userId)
  && request.resource.data.diff(resource.data)
      .affectedKeys().hasOnly(['equipped']);
```

### Role-based access (for multi-user apps)

```firestore
function hasRole(storeId, role) {
  return get(/databases/$(database)/documents/storeships/$(request.auth.uid + '_' + storeId)).data.role == role;
}
```

### Mandatory field validation on create

```firestore
// Enforce that id, createdAt are present on every new document
allow create: if isOwner(userId)
  && request.resource.data.keys().hasAll(['id', 'createdAt'])
  && request.resource.data.id == request.resource.id;
```

### Query limits

```firestore
allow list: if request.auth != null
  && request.query.limit <= 50;
```

### General rules

- **Deny by default** — only open what's needed
- **Never trust client-sent data** for prices, scores, permissions
- **Always validate field types** in rules for user-writable collections
- **Immutable documents** — for audit logs, use `allow create` without `allow update` or `allow delete`
- **createdAt immutability** — on update, enforce `createdAt` hasn't changed:

```firestore
allow update: if isOwner(userId)
  && request.resource.data.createdAt == resource.data.createdAt;
```

---

## Cloud Functions Structure

### Thin orchestrator + pure core modules

```
functions/src/
├── index.ts              — setGlobalOptions, all exports
├── {action-name}.ts      — onCall/onSchedule/trigger handlers (thin)
└── core/
    ├── {domain}.ts       — pure business logic (no DB calls)
    ├── {domain}.test.ts  — unit tests for pure functions
    └── helpers.ts        — shared utilities (dates, validation)
```

**Why separate `core/`?** Pure functions with no Firestore imports are trivially unit-testable. The handler reads from DB, calls pure functions, writes results back.

### Decompose into reusable functions

Each function should do ONE thing. If a handler has multiple logical steps with distinct responsibilities, extract them:

```typescript
// BAD — monolithic handler doing everything
export const createOrder = onCall(async (request) => {
  // 100 lines: validate, check stock, process payment, create order,
  // send notification, update analytics, decrement quantity...
});

// GOOD — orchestrator calling focused functions
export const createOrder = onCall(async (request) => {
  const uid = assertAuth(request);                          // reusable
  const input = validateCreateOrderInput(request.data);     // reusable
  
  const order = await db.runTransaction(async (tx) => {
    const offer = await readAndLockOffer(tx, input.offerId);    // reusable
    assertAvailability(offer, input.quantity);                   // reusable, pure
    const totalPrice = computePrice(offer, input.quantity);     // reusable, pure
    const orderId = createOrderDoc(tx, { uid, offer, input, totalPrice }); // reusable
    decrementOfferQuantity(tx, offer, input.quantity);          // reusable
    return orderId;
  });

  await sendOrderNotification(order);                       // reusable
  return { orderId: order.id };
});
```

**Benefits:**
- `assertAuth()` is reused by every callable function
- `computePrice()` is a pure function, easily unit-tested
- `decrementOfferQuantity()` is reused by cancel flow (with increment)
- `sendOrderNotification()` is reused by status change triggers

**Rule of thumb:** if a block of logic could be useful in another function — extract it. If it does something conceptually different from the surrounding code — extract it.

### Standard function pattern

Every callable function follows this structure:

```typescript
export const doSomething = onCall(async (request) => {
  // 1. Auth check
  const uid = assertAuth(request);

  // 2. Input validation
  const input = validateInput(request.data);

  // 3. Business logic (transaction if multi-doc)
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(docRef);           // read
    const result = computeSomething(doc.data()); // pure function
    tx.update(docRef, result);                   // write
  });

  // 4. Side effects (notifications, analytics) — outside transaction
  await notify(uid, 'something happened');
});
```

**Side effects (push notifications, emails, analytics) go OUTSIDE the transaction.** If the transaction retries, you don't want duplicate notifications.

### Reusable auth check

```typescript
// core/auth.ts — used by every callable function
export function assertAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  return uid;
}
```

### Reusable input validation

```typescript
// core/validation.ts
export function assertString(data: any, field: string): string {
  const value = data?.[field];
  if (typeof value !== 'string' || value.length === 0) {
    throw new HttpsError('invalid-argument', `${field} is required`);
  }
  return value;
}

export function assertPositiveInt(data: any, field: string): number {
  const value = data?.[field];
  if (!Number.isInteger(value) || value <= 0) {
    throw new HttpsError('invalid-argument', `${field} must be a positive integer`);
  }
  return value;
}
```

---

## Idempotency

Network retries, slow connections, and user double-taps can cause the same function to be called multiple times. Every function that creates data or modifies state **must be idempotent**.

### Strategy 1: Check-before-write (most common)

```typescript
export const createOrder = onCall(async (request) => {
  const uid = assertAuth(request);
  const { offerId, quantity } = request.data;

  // Idempotency key: unique per user + offer + date
  const idempotencyKey = `${uid}_${offerId}_${new Date().toISOString().split('T')[0]}`;

  await db.runTransaction(async (tx) => {
    // Check if this operation was already performed
    const existing = await tx.get(
      db.collection('orders').where('idempotencyKey', '==', idempotencyKey)
    );
    if (!existing.empty) {
      // Already processed — return existing result, don't create duplicate
      return existing.docs[0].data();
    }

    // First time — proceed with creation
    const orderRef = db.collection('orders').doc();
    tx.set(orderRef, {
      id: orderRef.id,
      idempotencyKey,
      // ... other fields
    });
  });
});
```

### Strategy 2: Deterministic document ID

Use a predictable ID so duplicate writes overwrite instead of creating duplicates:

```typescript
// Offer for a specific item on a specific date — only one should exist
const offerId = `${itemId}_${date}`; // deterministic
const offerRef = db.collection('offers').doc(offerId);

await offerRef.set({
  id: offerId,
  // ... fields
}, { merge: true }); // merge: don't overwrite fields not in this call
```

### Strategy 3: Status check before transition

```typescript
// Only transition if current status allows it
await db.runTransaction(async (tx) => {
  const order = await tx.get(orderRef);
  const currentStatus = order.data()?.status;

  // Idempotent: if already in target state, do nothing
  if (currentStatus === 'picked_up') return;

  // Guard: only valid transitions
  if (currentStatus !== 'ready') {
    throw new HttpsError('failed-precondition', `Cannot pick up from status: ${currentStatus}`);
  }

  tx.update(orderRef, { status: 'picked_up', pickedUpAt: FieldValue.serverTimestamp() });
});
```

### Rules

- **Every write function must have an idempotency strategy** — document it in comments
- **Cron functions are naturally idempotent** if they use deterministic IDs (Strategy 2)
- **Payment functions are the most critical** — always check-before-charge

---

## Race Condition Prevention

Firestore transactions are the primary tool for preventing race conditions. Without them, concurrent requests can read stale data and produce incorrect results.

### Problem: overselling

```typescript
// BAD — race condition: two users read quantity=1, both decrement
const offer = await offerRef.get();
if (offer.data().quantityRemaining > 0) {
  await offerRef.update({ quantityRemaining: offer.data().quantityRemaining - 1 });
  // Two concurrent calls both see quantityRemaining=1, both write 0
  // Result: quantity goes to 0, but TWO orders are created
}
```

### Solution: transactions

```typescript
// GOOD — transaction prevents concurrent read-modify-write
await db.runTransaction(async (tx) => {
  const offer = await tx.get(offerRef);
  const remaining = offer.data()!.quantityRemaining;

  if (remaining < quantity) {
    throw new HttpsError('failed-precondition', 'Not enough stock');
  }

  tx.update(offerRef, {
    quantityRemaining: remaining - quantity,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const orderRef = db.collection('orders').doc();
  tx.set(orderRef, {
    id: orderRef.id,
    offerId: offer.id,
    quantity,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
});
```

### When to use transactions

| Scenario | Transaction needed? |
|----------|-------------------|
| Read → compute → write (quantity decrement, balance update) | **Yes, always** |
| Create a new document with no dependencies | No |
| Update a single field unconditionally | No (use `FieldValue.increment`) |
| Update multiple documents that must be consistent | **Yes, always** |
| Status transition with guard (only if current status == X) | **Yes, always** |

### FieldValue.increment for simple counters

When you just need to add/subtract without reading first:

```typescript
// No transaction needed — atomic increment
await offerRef.update({
  quantityRemaining: FieldValue.increment(-1),
  updatedAt: FieldValue.serverTimestamp(),
});
```

**But:** if you need to CHECK the value before decrementing (e.g. don't go below 0), you MUST use a transaction.

### Batch writes for multi-document atomic writes (no reads needed)

```typescript
const batch = db.batch();
batch.set(orderRef, orderData);
batch.update(offerRef, { quantityRemaining: FieldValue.increment(-1) });
batch.set(notificationRef, notificationData);
await batch.commit();
// All three writes succeed or all fail — but no reads inside batch
```

### Transaction limits

- Max 500 document writes per transaction
- Transaction will retry up to 5 times on contention
- Keep transactions fast — no API calls, no slow computations inside
- Do reads first, then writes (Firestore requirement)

---

## Firestore Protection Checklist

Before deploying any collection, verify:

```
□ Security Rules written and tested
□ Every document has id, createdAt, updatedAt fields
□ createdAt is immutable (rules enforce no change on update)
□ Server-authoritative fields are blocked from client writes
□ Queries have limits (no unbounded list operations)
□ Composite indexes created for all compound queries
□ No client-side delete for critical data (orders, payments)
□ Sensitive fields (prices, quantities) are write-protected from client
□ Rules tested with Firebase Emulator (firebase emulators:exec --only firestore)
```

---

## Firebase Auth

### Auth state stream (Riverpod)

```dart
@Riverpod(keepAlive: true)
Stream<AppUser?> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}
```

### Custom claims

```typescript
// Server: set role
await admin.auth().setCustomUserClaims(uid, { role: 'admin' });
```

```dart
// Client: refresh after server update (claims are cached in token)
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

---

## Crashlytics

Always guard with `kIsWeb` — Crashlytics doesn't support web:

```dart
if (!kIsWeb) {
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
}
```

---

## Firebase Emulators

### Activation

```dart
// main.dart
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

if (useEmulators) {
  final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
}
```

```bash
# Run with emulators
flutter run --dart-define=USE_EMULATORS=true
```

### Default ports

| Service | Port |
|---------|------|
| Auth | 9099 |
| Firestore | 8081 |
| Functions | 5001 |
| Storage | 9199 |
| Emulator UI | 4000 |

### Host by platform

| Platform | Host |
|----------|------|
| iOS Simulator | `localhost` |
| Android Emulator | `10.0.2.2` |
| Physical device | LAN IP (`192.168.x.x`) |
| Web | `localhost` |

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---------|-----------------|
| Writing server-authoritative fields from client | Protect with Security Rules, write only from Cloud Functions |
| No transaction for read-modify-write | Always use `runTransaction` when reading before writing |
| Missing idempotency check | Every write function needs an idempotency strategy |
| `DateTime.now()` for timestamps | `FieldValue.serverTimestamp()` only |
| Documents without `id` field | Always store `id` equal to document ID |
| Documents without `createdAt` / `updatedAt` | Mandatory on every document |
| Hardcoding Cloud Functions region | Use project constant, document in `ai_docs` |
| Unbounded queries without `.limit()` | Always limit or scope to user |
| API calls inside transactions | Transactions should be fast — external calls go outside |
| Side effects inside transactions | Notifications, emails, analytics go after `commit` |
| Calling Crashlytics on web | Guard with `kIsWeb` |
| Forgetting `us-central1` for auth triggers | Firebase requires this region for auth triggers |
| Client-side price calculation | Server reads price from DB, never trusts client |
| Missing composite indexes | Deploy indexes for every compound query |

---

## Supabase RPC Function Security

When using Supabase instead of Firebase, RPC functions (`CREATE FUNCTION`) require their own security hardening. Every `SECURITY DEFINER` function must include all three:

1. **`SET search_path = public`** — prevents schema injection attacks
2. **Auth guard** — `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;` at the top of any function that writes user-scoped data
3. **REVOKE/GRANT** — restrict execution to `authenticated` role only:

```sql
REVOKE EXECUTE ON FUNCTION public.my_function(...) FROM anon;
GRANT EXECUTE ON FUNCTION public.my_function(...) TO authenticated;
```

Prefer `SECURITY INVOKER` (the default) for read-only functions that don't need to bypass RLS. Only use `SECURITY DEFINER` when the function needs elevated privileges (e.g., upsert across RLS-protected tables).