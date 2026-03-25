# Skill Memory: Agent Loop Patterns

## Purpose
Teaches Claude Code skills how to design autonomous agent loops using patterns from AutoGPT, crewAI, and babyagi. Focuses on task decomposition, role-based crews, ReAct loops, and safe iteration guardrails.

## Category notes
Belongs in orchestration — these patterns coordinate multi-step autonomous execution across tasks and agents.

## Relationships
Pairs with dispatching-parallel-agents (for swarm dispatch) and subagent-driven-development (for spawning subagents). claude-usage-orchestrator decides when to escalate to heavier models mid-loop.

## Maintenance notes
Cap guardrails (max_iterations=10, max_new_tasks=3) are conservative defaults. Adjust per use case but always document the cap.
