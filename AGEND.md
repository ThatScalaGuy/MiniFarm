## Project

The code project is managed with XcodeGen.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it. Don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Critique workflow

Run a critique using workflows when:

- I ask for a review, or
- you finished a non-trivial change: more than ~3 files, new features, changed public APIs, data/schema changes, concurrency, or security-relevant code.

Skip it for typos, formatting, renames, docs-only or config tweaks.

Hand the workflow only the task/goal and the changed files (git diff). Do not expose your reasoning or prior context. Let the workflow decide how to review.

Afterwards: verify the findings, fix the real ones, run tests, and re-run the critique on the fixes until nothing serious remains.

## Transparency

**For bigger tasks, maintain a task list and update it as you progress.**

- Use checkboxes to mark completed items.
- Update the list as you make progress.
- Keep it concise and focused on the task at hand.

## General Writing Guidelines

- Never use em dashes (—) or en dashes (–), neither in code comments, commit messages, documentation, nor in replies.
- Use a comma, period, colon, or parentheses instead. If a sentence feels like it needs a dash, rewrite it as two sentences.
- Write like a senior engineer in a hurry: direct, plain, no filler, no intros, no summaries of what you just did.
- Use simple English. Short sentences, common words, no idioms. It should read like a competent non-native speaker wrote it.
- Comments: only where the why is non-obvious. Never restate what the code does. Single line where possible. Terse and objective.
- Commits: imperative subject under 72 chars. Body only if the why isn't clear from the diff. No file lists, no emojis, no trailers.
- PRs: 2–5 sentences. What changed, why. No section headers unless the repo template has them.
- AVOID: delve, crucial, moreover, comprehensive, robust, seamless, leverage, ensure, "it's worth noting".
