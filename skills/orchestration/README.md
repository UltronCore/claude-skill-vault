# Orchestration Skills

This directory contains 23 skills for orchestrating AI agents, task pipelines, multi-agent systems, and execution workflows.

## Skills in this category

| Skill | Description |
|-------|-------------|
| [adaptive-codex-utilization](adaptive-codex-utilization/SKILL.md) | Route tasks to Claude or Codex based on whether they are execution-heavy or reasoning-heavy |
| [adaptive-private-memory-engine](adaptive-private-memory-engine/SKILL.md) | Recall personal context, resume prior work, and maintain private memory with selective loading |
| [adaptive-private-memory-engine-misc](adaptive-private-memory-engine-misc/SKILL.md) | Route memory recall and writes — loads minimum relevant context, never reads all memory |
| [agent-loop-patterns](agent-loop-patterns/SKILL.md) | Design autonomous agent loops, task queues, and multi-agent crew systems with Claude |
| [agent-safety](agent-safety/SKILL.md) | Detect and block prompt injection, PII/PHI leakage, repo poisoning, and adversarial inputs |
| [autonomous-knowledge-system](autonomous-knowledge-system/SKILL.md) | Default operating system for all tasks — autonomous multi-agent execution with knowledge capture |
| [claude-usage-orchestrator](claude-usage-orchestrator/SKILL.md) | Control Claude Code usage discipline — minimize costs, route by complexity, reuse existing outputs |
| [context-engineer](context-engineer/SKILL.md) | Clarify scope, inputs, and framing before execution on complex or ambiguous tasks |
| [crewai](crewai/SKILL.md) | Multi-agent orchestration with role-based collaboration using CrewAI |
| [data-orchestration](data-orchestration/SKILL.md) | Route data pipeline tasks — ETL, workflow orchestration, stream processing, and ingestion |
| [dispatching-parallel-agents](dispatching-parallel-agents/SKILL.md) | Dispatch parallel subagents for 2+ independent tasks that have no shared state |
| [executing-plans](executing-plans/SKILL.md) | Execute written implementation plans in separate sessions with review checkpoints |
| [langgraph](langgraph/SKILL.md) | Build stateful multi-actor AI applications with cyclic graphs using LangGraph |
| [multi-agent-orchestration](multi-agent-orchestration/SKILL.md) | Design orchestrator-worker multi-agent systems with parallel execution and error recovery |
| [output-guardrails](output-guardrails/SKILL.md) | Add safety validation and output constraints to Claude Code skill outputs |
| [planning-with-files](planning-with-files/SKILL.md) | Implement persistent markdown-based planning where plans are files executed step-by-step |
| [prompt-chaining](prompt-chaining/SKILL.md) | Build reliable multi-step LLM pipelines with gate conditions, parallel chains, and error handling |
| [prompt-injection-defense](prompt-injection-defense/SKILL.md) | Defend LLM apps against prompt injection — input sanitization, instruction hierarchy, and detection |
| [rag-pipeline](rag-pipeline/SKILL.md) | Build and optimize RAG pipelines — document ingestion, indexing, retrieval, and search backends |
| [self-healing-execution](self-healing-execution/SKILL.md) | Ensure code, scripts, and automations are complete and stable before stopping |
| [subagent-driven-development](subagent-driven-development/SKILL.md) | Execute implementation plans with independent tasks using subagents in the current session |
| [system-builder](system-builder/SKILL.md) | Build reusable systems, skills, workflows, and execution-ready outputs for non-trivial tasks |
| [ultra-lovable-orchestrator](ultra-lovable-orchestrator/SKILL.md) | High-quality orchestrated output for multi-step creative and technical tasks |

## Related Categories
- [ai-ml](../ai-ml/README.md) — AI frameworks and model orchestration
- [misc](../misc/README.md) — utility and routing skills
- [workflow](../workflow/README.md) — cross-tool workflow patterns
