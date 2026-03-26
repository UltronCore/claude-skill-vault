# Skill Memory: adaptive-private-memory-engine

## Purpose
Manages private personal memory for Claude Code. Routes selectively, writes compactly, enforces privacy.

## Memory Home
~/.claude/memory/

## Supporting Files
- memory-schema.md — templates and schemas (no personal data)
- skill-optimizer.md — skill efficiency analysis routine (separate from personal memory)

## Key Behaviors
- Staged retrieval: alias → index → summary → detail
- Write classification before any memory write
- Tiered privacy checks
- Lightweight maintenance by default
