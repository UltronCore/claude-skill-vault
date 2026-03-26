# Claude Usage Orchestrator

**Category:** optimization
**Status:** active
**Version:** v1

## What it does
Operates Claude Code with disciplined usage control by routing tasks through the lightest sufficient reasoning path, reusing existing skills and prior outputs, and integrating with the Codex skill for mechanical execution work.

## When to use
- Optimizing token usage and reducing unnecessary API consumption on any task
- Routing task complexity through minimal, standard, intensive, or offload lanes
- Deciding whether to handle work in Claude or offload to Codex
- Applying usage-aware orchestration principles before beginning a complex workflow

## What it produces
A structured triage decision (routing lane selection), a scoped execution plan, and completed work using the smallest sufficient reasoning path with clean, direct output.

## Related skills
- server-actions-vs-api-optimizer (benefits from usage-aware routing)
- performance-budget-enforcer (benefits from usage-aware routing)
