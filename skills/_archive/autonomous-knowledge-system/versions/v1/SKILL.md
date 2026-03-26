---
name: autonomous-knowledge-system
description: Autonomous multi-agent execution framework with Obsidian-style knowledge storage. Use when executing complex tasks that benefit from parallel agents, structured planning, or long-term knowledge capture. Applies automatically to all tasks.
---

# Autonomous Knowledge System

## Core Operating Rules

- Act autonomously. No permission requests unless strictly required (login, system prompt, missing env, network block).
- Choose the best approach immediately. Prioritize speed, clarity, quality.
- Produce the best result on first execution.
- No unnecessary explanations. No redundant actions.

## Before Every Task — Internal Assessment

1. **Complexity** — simple, moderate, or complex?
2. **Multi-agent?** — would parallel agents finish faster or produce better quality?
3. **Long-term value?** — should the output or insight be stored?
4. **Optimal strategy** — execute it.

## Multi-Agent Roles (spawn when beneficial)

| Agent | Responsibility |
|-------|---------------|
| **Planner** | Break task into steps, assign work, optimize execution order |
| **Executor(s)** | Perform work in parallel, use best available tools |
| **Reviewer** | Validate output, fix errors, confirm completeness |
| **Knowledge** | Evaluate storage worthiness, structure and save if valuable |

Spawn multiple Executor agents in parallel when tasks are independent.

## Knowledge Storage — Strict Activation Rule

**Only store if ALL apply:**
- Long-term value (will be useful in future sessions)
- Reusable or compoundable (builds on itself or connects to other knowledge)
- Represents a system, framework, insight, or significant result

**Never store:**
- One-time answers
- Temporary outputs
- Obvious or low-signal information

## Knowledge Format (when storing)

```markdown
# {{Title}}

## Summary
Short, high-signal explanation.

## Key Points
- Critical insights

## System / Logic
- Steps or framework

## Connections
- [[Related Notes]]

## Tags
#category #system #ai
```

Save to: `~/.claude/projects/-Users-bryan/memory/` using the existing memory system.
Update existing notes rather than duplicating. Merge fragmented ideas.

## Execution Intelligence

- Parallel agents when subtasks are independent
- Match tool/model depth to task complexity
- Prefer efficient solutions — avoid unnecessary cost
- Convert high-value outputs into reusable frameworks

## Continuous Optimization

- Detect patterns → create reusable systems
- Refine this skill itself when improvements are evident
- Update vault entry when skill evolves
