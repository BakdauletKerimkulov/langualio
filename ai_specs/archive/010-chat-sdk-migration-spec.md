---
title: Migrate chat edge function to Anthropic SDK
status: done
date: 2025-07-25
type: refactor
severity: M
references: []
---

## Symptom
`chat/index.ts` had broken duplicate code: a non-functional Anthropic SDK stub (hardcoded API key string, `message` variable shadowing) followed by the old raw `fetch()` call. The function would crash at runtime due to the `message` const redeclaration. Also used wrong import path (`@anthropic-ai/sdk/index.mjs`).

## Root cause
Incomplete migration to Anthropic SDK. `generate-word-entry/index.ts` was fully migrated, but `chat/index.ts` was left with a broken half-attempt pasted on top of the old `fetch()` code at `chat/index.ts:101-125`.

## Fix
- **Files changed:** `supabase/functions/chat/index.ts`, `supabase/functions/_shared/constants.ts`
- **Failing test that catches the regression:** no automated test (edge function on Deno runtime, no test infra for this)
- **`ai_toolkit/` rules applied:** `edge-functions.md` (External APIs: requireEnv for secrets, validate AI response; Handler Flow: numbered steps; Config: fail fast on missing env)
- **Toolkit deviations:** none
- Replaced raw `fetch()` + broken SDK stub with proper `Anthropic` SDK client usage matching `generate-word-entry/index.ts` pattern. Fixed import path. Removed unused `CLAUDE_API_URL` export from constants.
