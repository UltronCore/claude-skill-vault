# Skill Memory: Finishing a Development Branch

## Purpose
This skill standardizes branch completion by verifying tests first, presenting exactly four options, and handling worktree cleanup correctly. The typed "discard" confirmation requirement and the worktree-cleanup-only-for-options-1-and-4 rule are critical safety constraints.

## Category notes
Classified as orchestration because it manages the final coordination step of a development workflow — integrating completed work back into the main branch.

## Relationships
- subagent-driven-development: calls this skill at Step 7 after all tasks complete
- executing-plans: calls this skill after all batches complete
- using-git-worktrees: this skill cleans up the worktree that using-git-worktrees created

## Maintenance notes
None.
