# Brainstorming

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Guides collaborative design sessions that turn ideas into fully specified, approved design documents before any implementation begins. Asks clarifying questions one at a time, proposes multiple approaches with trade-offs, presents designs section-by-section for approval, then writes and reviews a spec document before handing off to writing-plans.

## When to use
- Before building any new feature, component, or functionality
- When requirements are unclear or underspecified
- Before entering plan mode or starting implementation
- When a project needs to be decomposed into sub-projects first

## What it produces
A committed design spec document at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` that has passed automated review and user approval, ready for writing-plans to consume.

## Related skills
writing-plans, subagent-driven-development, executing-plans, using-git-worktrees
