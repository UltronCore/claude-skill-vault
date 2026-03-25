---
name: agent-loop-patterns
description: Design patterns for building autonomous agent loops, task queues, and multi-agent crew systems with Claude. Use when building self-directed agents, task decomposition systems, or role-based agent workflows. Trigger when users want autonomous execution, agent loops, task planning, crew-based agents, or self-improving workflows.
---

# Agent Loop Patterns

Autonomous agent loops allow Claude to plan, execute, observe, and iterate without constant human input. These patterns come from AutoGPT, crewAI, and babyagi — distilled into Claude Code-compatible implementations.

## Pattern 1: Minimal task loop (BabyAGI-style)
The simplest autonomous loop: create task, execute, generate next tasks.

```python
from collections import deque

task_queue = deque()
task_queue.append("Research topic X and summarize findings")
completed = []

while task_queue:
    task = task_queue.popleft()
    # Execute with Claude
    result = execute_task(task)
    completed.append({"task": task, "result": result})
    # Generate next tasks based on result
    new_tasks = generate_next_tasks(task, result, completed)
    task_queue.extend(new_tasks[:3])  # cap expansion
```

## Pattern 2: Role-based crew (crewAI-style)
Assign specialized roles to agents for collaborative work.

```
Crew:
  - Researcher: finds information, returns structured findings
  - Analyst: interprets findings, identifies patterns
  - Writer: synthesizes analysis into final output

Each agent:
  - Has a clear role and backstory
  - Receives only relevant context
  - Passes output to next agent
  - Does NOT have access to other agents' tools
```

In Claude Code terms: spawn one subagent per role, pass context explicitly.

## Pattern 3: ReAct loop (Reason + Act)
Standard agentic loop: think → tool call → observe → think again.

```
Step 1: THOUGHT — What do I need to do?
Step 2: ACTION — Call tool (bash, read, web search)
Step 3: OBSERVATION — What did the tool return?
Step 4: THOUGHT — Did this complete the goal? If not, repeat.
Step 5: FINAL ANSWER — Return result when done
```

In Claude Code: this is the default behavior. Reinforce it by structuring prompts as:
"Think step by step. Use tools as needed. Return only when you have a complete answer."

## Pattern 4: Swarm dispatch (AutoGPT-style parallelism)
Split independent tasks across parallel agents, merge results.

```python
# Split
subtasks = decompose_goal(main_goal)  # list of independent tasks

# Dispatch in parallel (Claude Code Agent tool)
# Each agent handles one subtask independently
# Coordinator merges results

# This maps directly to superpowers:dispatching-parallel-agents
```

## Guardrails for agent loops
- Always cap iteration count (max_iterations=10 default)
- Always cap task queue growth (max_new_tasks=3 per step)
- Always have an explicit completion condition
- Log every step — loops that don't log become undebuggable
- Test with a 2-step loop before running full autonomy

## Related skills
dispatching-parallel-agents, subagent-driven-development, claude-usage-orchestrator
