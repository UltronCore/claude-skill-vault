# Skill Memory: Using Superpowers

## Purpose
This is the meta-skill that governs all skill invocation behavior. It establishes the 1% rule (if there's even a 1% chance a skill applies, invoke it), the priority order (user instructions > superpowers skills > default system prompt), and the distinction between rigid skills (follow exactly) and flexible skills (adapt principles). It is not intended for subagents executing specific tasks.

## Category notes
Classified as app-usage because it is specifically about how to use the Claude Code superpowers plugin system, not about any implementation technique.

## Relationships
All superpowers skills — this skill is the prerequisite meta-protocol for all of them. The brainstorming skill is specifically highlighted as having special invocation timing (before entering plan mode).

## Maintenance notes
Contains platform-specific guidance for Claude Code, Gemini CLI, and Codex. The SUBAGENT-STOP block prevents subagents from loading this skill unnecessarily.
