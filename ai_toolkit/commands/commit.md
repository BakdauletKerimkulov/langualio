Review staged and unstaged changes:
!`git status --short`
!`git diff HEAD`

1. Run the review checklist from ai_toolkit/commands/review.md mentally.
   If red flags found — report them and DO NOT commit.

2. If clean, stage all changes:
   git add -A

3. Write commit message in Conventional Commits format:
   type(scope): description

   Types: feat, fix, refactor, docs, style, test, chore
   Scope: feature name (auth, offers, orders, payments, etc.)
   Description: imperative, lowercase, no period

   Examples:
   - feat(offers): add offer map screen with geo-query
   - fix(orders): prevent double-decrement on concurrent reservations
   - refactor(auth): extract onboarding state machine to separate file
   - docs(ai_docs): add payment integration documentation

4. Commit:
   git commit -m "type(scope): description"

5. If $ARGUMENTS provided, use as context for the commit message.