# Finishing a Development Branch

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Verifies tests pass, then presents exactly four structured options for completing development work: merge locally, push and create a PR, keep as-is, or discard. Handles the chosen option including worktree cleanup.

## When to use
- After all implementation tasks are complete and verified
- Before merging any feature branch
- At the end of executing-plans or subagent-driven-development workflows

## What it produces
A clean branch integration (merge, PR, or documented hold) with worktree cleanup completed for options 1 and 4.

## Related skills
subagent-driven-development, executing-plans, using-git-worktrees
