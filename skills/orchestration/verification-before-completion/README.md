# Verification Before Completion

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Requires running the actual verification command and reading its full output before making any claim of success, completion, or correctness. Identifies and blocks a comprehensive list of common failure modes including "should pass," "looks correct," trusting agent reports, and expressing satisfaction before evidence is in hand.

## When to use
- Before claiming any work is done, fixed, or passing
- Before committing, creating PRs, or marking tasks complete
- Whenever about to express satisfaction or move to the next task

## What it produces
Evidence-backed status reports: either a confirmed passing verification with output shown, or an honest statement of the actual failing state.

## Related skills
test-driven-development, systematic-debugging, subagent-driven-development
