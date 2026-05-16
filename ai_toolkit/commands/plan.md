Read the following files in order:
1. ai_toolkit/guidelines/ (all files)
2. All files listed in the "Context → Read:" section of the requirements
3. The requirements file: ai_specs/{current-feature}/requirements.md

Generate a detailed implementation plan.

Save the plan to ai_specs/{current-feature}/plan.md

Plan format:

# Plan: {Feature Name}

Source: ai_specs/{folder}/requirements.md
Created: {date}

## Overview
One paragraph: what will be built.

## Stages

### Stage 1: {Name}
**Goal:** What this stage achieves
**Files to create/modify:**
- `path/to/file.dart` — what it does
**Steps:**
- [ ] Step 1
- [ ] Step 2
**Verification:** How to confirm this stage works

### Stage 2: {Name}
...

## Firestore Changes
New collections, fields, indexes, or security rules needed.

## Cloud Functions
New or modified functions.

## Risks & Open Questions
Anything uncertain or needing clarification.

Rules:
- 3-7 steps per stage, small enough to review
- Each stage independently verifiable
- Do NOT write code — only the plan
- Respect Out of Scope from requirements