Read ai_toolkit/guidelines/ (all files).

Review all staged/unstaged changes:
!`git diff HEAD`

Check for:

1. Code style violations (code-style.md):
   - Naming conventions
   - File size > 300 lines
   - Private widget methods instead of extracted classes
   - Raw numbers instead of Sizes/gaps
   - print() instead of debugPrint/AppLogger
   - Missing const constructors

2. Architecture violations (architecture.md):
   - Firebase imports in domain/ layer
   - Business logic in presentation/ layer
   - Repository returning Map/DocumentSnapshot instead of domain model
   - TimestampConverter on domain model instead of DTO
   - Navigator.push instead of GoRouter

3. Riverpod violations (riverpod.md):
   - ref.watch inside async methods
   - Missing _mounted check after await in auto-dispose controllers
   - Provider created for ephemeral/UI-only state
   - Legacy StateProvider/StateNotifierProvider

4. Firebase violations (firebase.md):
   - Missing id/createdAt/updatedAt on documents
   - Client-side timestamps instead of FieldValue.serverTimestamp()
   - Read-modify-write without transaction
   - Missing idempotency strategy
   - Client writing server-authoritative fields

5. Flutter violations (flutter.md):
   - Deprecated APIs (withOpacity, old TextTheme names, etc.)
   - Platform.isIOS without kIsWeb check

If violations found:
  - List each with file path and line
  - Suggest fix
  - Do NOT commit

If clean:
  - Report "No violations found. Ready to commit."