# Skill Memory: Brainstorming

## Purpose
This skill enforces a collaborative design-before-implementation workflow. It prevents premature coding by requiring a spec document to be written, reviewed by a subagent, and approved by the user before any implementation skill is invoked. The only valid next step after this skill is writing-plans.

## Category notes
Classified as orchestration because it coordinates the design phase of the development lifecycle and gates entry into implementation workflows.

## Relationships
- writing-plans: mandatory downstream skill — brainstorming always hands off to writing-plans
- using-git-worktrees: called after design is approved when implementation follows
- subagent-driven-development / executing-plans: downstream of writing-plans, not directly invoked by this skill
- frontend-design: explicitly NOT invoked by this skill even for UI projects

## Maintenance notes
The HARD-GATE block is critical to preserve — it explicitly forbids implementation before design approval. The Visual Companion section references a local file (skills/brainstorming/visual-companion.md) that is not included in this vault import.
