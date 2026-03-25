# Subagent-Driven Development

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Executes implementation plans by dispatching a fresh subagent per task with isolated context, followed by a mandatory two-stage review: spec compliance first, then code quality. The orchestrator extracts all tasks upfront, manages the review loop for each, and dispatches a final overall review before completing.

## When to use
- When you have a written implementation plan with mostly independent tasks
- When staying in the current session (vs. parallel session handoff)
- For high-quality implementation with automatic review checkpoints after every task

## What it produces
A fully implemented and doubly-reviewed feature with all tasks committed, ready for finishing-a-development-branch.

## Related skills
writing-plans, executing-plans, requesting-code-review, finishing-a-development-branch, using-git-worktrees, test-driven-development
