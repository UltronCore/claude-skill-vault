# Skill Memory: Using Git Worktrees

## Purpose
This skill standardizes isolated workspace creation with a strict priority order for directory selection (existing > CLAUDE.md preference > ask user), mandatory gitignore verification for project-local directories, auto-detected dependency installation, and a clean baseline test verification before any implementation begins.

## Category notes
Classified as orchestration because it sets up the isolated environment that all implementation workflows depend on.

## Relationships
- subagent-driven-development: required setup before execution
- executing-plans: required setup before execution
- finishing-a-development-branch: cleans up the worktree this skill created
- brainstorming: may call this skill when transitioning to implementation after design approval

## Maintenance notes
None.
