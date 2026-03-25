# Writing Plans

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Creates comprehensive, bite-sized implementation plans from specs or requirements, mapping exact file paths and responsibilities before decomposing into tasks. Each task includes TDD steps with exact commands and expected outputs. Plans are reviewed by a subagent reviewer before offering the choice of subagent-driven or inline execution.

## When to use
- After brainstorming produces an approved spec
- Before touching any code on a multi-step feature
- When requirements are clear enough to produce exact file paths and implementation steps

## What it produces
A saved plan document at `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` that has passed plan review, with execution handed off to either subagent-driven-development or executing-plans.

## Related skills
brainstorming, subagent-driven-development, executing-plans, using-git-worktrees
