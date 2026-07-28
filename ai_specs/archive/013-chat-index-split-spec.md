---
title: Split chat/index.ts into handler + prompt module
status: done
date: 2026-07-23
type: refactor
severity: S
references: [edge-functions.md → ~200 line guideline]
---

## Symptom
`supabase/functions/chat/index.ts` was 233 lines — exceeding the ~200 line guideline in `edge-functions.md`. Pure logic functions were inlined in the handler file.

## Root cause
`sanitizeContextPayload()`, `buildSystemPrompt()`, and `CEFR_LABELS` are self-contained pure functions with no handler dependency. They lived inline in `index.ts` instead of being extracted to a sibling module per the toolkit pattern.

## Fix
- **Files changed:** `supabase/functions/chat/index.ts`, `supabase/functions/chat/prompt.ts` (new), `supabase/functions/chat/prompt_test.ts` (new)
- **Failing test that catches the regression:** `supabase/functions/chat/prompt_test.ts` (10 tests covering sanitize + buildSystemPrompt)
- **`ai_toolkit/` rules applied:** `edge-functions.md` → split pure logic into sibling modules when index.ts > ~200 lines
- **Toolkit deviations:** none
- **Result:** `index.ts` reduced from 233 to 167 lines. `prompt.ts` (68 lines) contains the extracted pure functions. No behavior change.
