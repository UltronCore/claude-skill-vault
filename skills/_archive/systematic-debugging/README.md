# Systematic Debugging

**Category:** research
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Enforces a four-phase debugging methodology: root cause investigation, pattern analysis, hypothesis testing, and implementation. Prohibits proposing any fix before completing Phase 1, and requires stopping for architectural discussion after three failed fix attempts rather than continuing to guess.

## When to use
- Any time a bug, test failure, or unexpected behavior is encountered
- Especially under time pressure when guessing is tempting
- When a "quick fix" seems obvious but root cause is unknown
- After two or more failed fix attempts on the same issue

## What it produces
A verified fix addressing the true root cause, with a failing test written first and all existing tests still passing.

## Related skills
test-driven-development, verification-before-completion, dispatching-parallel-agents
