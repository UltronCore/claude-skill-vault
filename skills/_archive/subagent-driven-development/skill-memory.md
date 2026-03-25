# Skill Memory: Subagent-Driven Development

## Purpose
This skill is the primary high-quality implementation workflow. It dispatches a fresh subagent per task (no context pollution), enforces two-stage review (spec compliance then code quality — in that order), and handles four implementer status codes (DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED). Model selection guidance matches task complexity to the cheapest capable model.

## Category notes
Classified as orchestration because it is the central coordinator of a full implementation cycle with multiple specialized subagents.

## Relationships
- writing-plans: creates the plan this skill executes
- executing-plans: alternative for parallel session execution
- requesting-code-review: provides the code review template used here
- finishing-a-development-branch: called after all tasks complete
- using-git-worktrees: required setup before execution
- test-driven-development: subagents should use this skill for each task

## Maintenance notes
References three prompt template files (implementer-prompt.md, spec-reviewer-prompt.md, code-quality-reviewer-prompt.md) that are not included in this vault import.
