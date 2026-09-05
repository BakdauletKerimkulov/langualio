# Archived Specifications

Specs moved here on 2026-07-26. Key decisions preserved in `ai_docs/solutions/architecture-decisions.md`.

## Status Legend
- **done** — fully implemented and shipped
- **done (QA pending)** — code complete, needs integration testing
- **partial** — some phases done, remaining work deferred
- **superseded** — replaced by newer specs

---

| # | Name | Status | Notes |
|---|------|--------|-------|
| 001 | Word Quiz Feature | done | All 6 phases complete |
| 002 | Chat Feature Refactoring | done | Pagination, history loading, mock removal |
| 003 | Registration Flow | done | Onboarding + CEFR assessment |
| 004 | Admin Panel | done | Word management + AI generation |
| 005 | Revise WordEntry Model | done (QA pending) | Multi-meaning support, Phase 6 QA skipped |
| 006 | Local-Remote Quiz Refactor | superseded | Replaced by 008 + 009 |
| 007 | Project Audit | partial | Phases 1–6 done; Phase 7 (.hardcoded sweep) incomplete |
| 008 | Adding Words to Assets | done | B1 vocabulary JSON bundle |
| 009 | Refactor Quiz Repo | done | Local-only pool + user word addition |
| 010 | AI Chat Audit | done | JSON mode + SDK migration; SSE streaming deferred |
| 011 | Chat Provider Import Fix | done | Duplicate storage_provider.dart fix |
| 012 | Global Project Review | done | Full codebase review |
| 013 | Chat Index Split | done | Edge function modularization |
| — | initial-requirements.md | reference | Original project requirements |
