# Using Git Worktrees

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Creates an isolated git worktree for feature work by following a priority-based directory selection process, verifying the directory is gitignored, running project setup, and confirming a clean test baseline before any implementation begins.

## When to use
- Before starting any feature work that needs branch isolation
- Required before executing-plans or subagent-driven-development
- When working on multiple branches of the same repository simultaneously

## What it produces
A ready worktree at a confirmed path with dependencies installed and a verified passing test baseline, plus a gitignore entry if needed.

## Related skills
subagent-driven-development, executing-plans, finishing-a-development-branch, brainstorming
