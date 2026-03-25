# Skill Memory: Executing Plans

## Purpose
This skill provides the inline, same-session plan execution path for teams or contexts where subagents are unavailable or where a human-in-loop checkpoint model is preferred. It emphasizes stopping on blockers rather than guessing, and always completing with finishing-a-development-branch.

## Category notes
Classified as orchestration because it manages sequential task execution from a written plan document.

## Relationships
- writing-plans: creates the plans this skill executes
- subagent-driven-development: preferred alternative when subagents are available in the same session
- finishing-a-development-branch: required completion step
- using-git-worktrees: required setup before execution begins

## Maintenance notes
None.
