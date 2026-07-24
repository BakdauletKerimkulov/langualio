# Templates

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

## Feature Requirements (`ai_specs/{feature}/requirements.md`)

```markdown
# Feature: [Name]

## Context
Read: [list relevant ai_docs/ or ai_toolkit/ files the AI should read first]

## What
[1-3 sentences describing the feature and its role in the app.]

## User Flow
1. ...
2. ...
3. ...

## Technical Constraints
- [Package/library choices]
- [State management: Riverpod]
- [Routing: GoRouter]
- [Platform-specific notes]

## Data Source
Table / collection: [name]
Fields needed: [field1], [field2], ...
Backend: [RPC / server function, if any]

## Out of Scope (do NOT implement)
- [Feature X (Phase N)]
- [Feature Y (separate app/module)]

## Acceptance Criteria
- [Measurable outcome 1]
- [Measurable outcome 2]
- [Edge case handling]
```

## Plan (`ai_specs/{feature}/plan.md`)

Format is defined in `commands.md` → `/plan`.
