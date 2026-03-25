# Executing Plans

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Loads a written implementation plan, critically reviews it for gaps or concerns, then executes each task step-by-step with verification checkpoints. Stops immediately when blocked rather than guessing, and concludes by invoking finishing-a-development-branch.

## When to use
- When you have a written plan and want to execute it in a separate parallel session
- For batch execution with human-in-loop checkpoints between tasks
- As an alternative to subagent-driven-development when parallel session handoff is preferred

## What it produces
A fully implemented feature with all plan tasks completed and verified, handed off to finishing-a-development-branch for merge/PR/cleanup.

## Related skills
writing-plans, subagent-driven-development, finishing-a-development-branch, using-git-worktrees
