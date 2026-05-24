---
name: planning-with-files
description: Implement persistent markdown-based planning for AI agents — the Manus-style workflow pattern where plans are written as files, executed step-by-step, and updated to reflect progress. Enables long-running reliable execution.
version: 1.0.0
tags: [planning, agent, markdown, persistent-state, manus-style, execution, task-management]
---

# Planning with Files

## Overview

This skill implements the "planning-with-files" pattern — writing task plans as structured markdown files that serve as persistent state for AI agents across long-running tasks. Each plan tracks objectives, steps (with status), blockers, and progress. The agent reads the plan, executes the next step, updates the file, and repeats. This pattern enables reliable execution of complex multi-step tasks with full transparency and resumability.

## When to Use

- Multi-step tasks that may take more than one context window to complete
- Tasks requiring coordination across multiple tool calls or sub-agents
- When you need full audit trail of what was planned vs. what was done
- Complex debugging or research tasks with many branches
- Any agentic workflow where a human may need to intervene or review progress

## Step-by-Step Workflow

### 1. Plan File Structure
```markdown
# Task: [Clear objective in one sentence]

## Status: IN_PROGRESS | BLOCKED | COMPLETE | FAILED
## Created: 2026-05-24
## Updated: 2026-05-24T10:30:00Z

## Objective
[1-3 sentences describing what success looks like]

## Context
[Key facts, constraints, prior decisions relevant to this task]

## Plan

### Step 1: [Action verb + specific outcome] 
- Status: DONE ✓
- Started: 2026-05-24T10:00:00Z  
- Completed: 2026-05-24T10:05:00Z
- Result: Found 3 configuration files in /etc/nginx/
- Notes: conf.d/ directory has 12 additional includes

### Step 2: [Next step]
- Status: IN_PROGRESS ⟳
- Started: 2026-05-24T10:05:00Z
- Result: [pending]

### Step 3: [Future step]
- Status: PENDING ○
- Depends on: Step 2

### Step 4: Validate results
- Status: PENDING ○

## Blockers
[None | Description of what's blocking progress]

## Decisions Made
- [Date]: Chose approach X over Y because [reason]

## Notes / Discoveries
- [Important context learned during execution]
```

### 2. Agent Execution Loop (Python)
```python
import os
import re
from pathlib import Path
from datetime import datetime
from anthropic import Anthropic

client = Anthropic()

def create_plan(task: str, plan_dir: str = "/tmp/plans") -> Path:
    """Create initial plan file for a task."""
    os.makedirs(plan_dir, exist_ok=True)
    plan_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    plan_path = Path(plan_dir) / f"plan_{plan_id}.md"
    
    # Ask LLM to create the plan
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": f"""Create a detailed execution plan for this task. 
Write it as a markdown file with:
- Clear objective
- 4-8 concrete, actionable steps with specific outcomes
- Status: PENDING for all steps

Task: {task}

Format each step as:
### Step N: [Action verb + specific outcome]
- Status: PENDING ○"""
        }]
    )
    
    plan_content = f"# Task: {task}\n\n## Status: IN_PROGRESS\n## Created: {datetime.now().isoformat()}\n\n"
    plan_content += response.content[0].text
    
    plan_path.write_text(plan_content)
    print(f"Plan created: {plan_path}")
    return plan_path

def get_next_step(plan_content: str) -> tuple[int, str] | None:
    """Find the next PENDING or IN_PROGRESS step."""
    steps = re.findall(
        r'### Step (\d+): (.+?)\n- Status: (PENDING|IN_PROGRESS)',
        plan_content,
        re.MULTILINE
    )
    
    # First: any IN_PROGRESS step (resume interrupted work)
    for num, title, status in steps:
        if status == "IN_PROGRESS":
            return int(num), title
    
    # Then: first PENDING step
    for num, title, status in steps:
        if status == "PENDING":
            return int(num), title
    
    return None  # All done

def update_step_status(plan_path: Path, step_num: int, status: str, result: str = ""):
    """Update a step's status and result in the plan file."""
    content = plan_path.read_text()
    
    # Mark as IN_PROGRESS
    if status == "IN_PROGRESS":
        content = re.sub(
            rf'(### Step {step_num}: .+?\n- Status: )PENDING ○',
            rf'\1IN_PROGRESS ⟳\n- Started: {datetime.now().isoformat()}',
            content
        )
    elif status == "DONE":
        content = re.sub(
            rf'(### Step {step_num}: .+?\n- Status: )IN_PROGRESS ⟳\n- Started: .+?$',
            rf'\1DONE ✓\n- Completed: {datetime.now().isoformat()}\n- Result: {result}',
            content,
            flags=re.MULTILINE
        )
    elif status == "FAILED":
        content = re.sub(
            rf'### Step {step_num}:',
            rf'### Step {step_num} [FAILED]:',
            content
        )
        content += f"\n\n## Blockers\n- Step {step_num} failed: {result}\n"
    
    plan_path.write_text(content)

def execute_plan(plan_path: Path, available_tools: dict):
    """Execute plan steps until completion or failure."""
    max_iterations = 20
    
    for iteration in range(max_iterations):
        content = plan_path.read_text()
        next_step = get_next_step(content)
        
        if not next_step:
            # All steps done — mark plan complete
            content = content.replace("## Status: IN_PROGRESS", "## Status: COMPLETE")
            plan_path.write_text(content)
            print("Plan completed successfully!")
            return True
        
        step_num, step_title = next_step
        print(f"\nExecuting Step {step_num}: {step_title}")
        
        update_step_status(plan_path, step_num, "IN_PROGRESS")
        
        try:
            # Execute the step using LLM + tools
            result = execute_step_with_llm(step_title, content, available_tools)
            update_step_status(plan_path, step_num, "DONE", result[:200])
        except Exception as e:
            update_step_status(plan_path, step_num, "FAILED", str(e)[:200])
            print(f"Step {step_num} failed: {e}")
            return False
    
    print("Max iterations reached without completion")
    return False
```

### 3. Minimal Plan Template (Paste-and-Go)
```markdown
# Task: [YOUR TASK HERE]

## Status: IN_PROGRESS
## Created: 2026-05-24

## Objective
[What success looks like]

## Plan

### Step 1: Research and gather requirements
- Status: PENDING ○
- Result: 

### Step 2: Design the solution approach
- Status: PENDING ○
- Depends on: Step 1
- Result: 

### Step 3: Implement core functionality
- Status: PENDING ○
- Depends on: Step 2
- Result: 

### Step 4: Test and validate
- Status: PENDING ○
- Result: 

### Step 5: Document and finalize
- Status: PENDING ○
- Result: 

## Decisions Made

## Notes
```

### 4. Plan Review and Update Cycle
```python
def review_and_adapt_plan(plan_path: Path):
    """After each step, check if the plan needs updating based on discoveries."""
    content = plan_path.read_text()
    
    review = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Review this execution plan. 
Based on completed steps and results, should any PENDING steps be:
1. Revised to better match what was discovered?
2. Added (new steps needed)?
3. Removed (no longer necessary)?

Reply with 'NO_CHANGES' or describe specific modifications needed.

Plan:
{content}"""
        }]
    )
    
    review_text = review.content[0].text
    
    if "NO_CHANGES" not in review_text:
        # Apply suggested modifications
        updated = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2048,
            messages=[{
                "role": "user",
                "content": f"Apply these plan modifications while preserving completed steps:\n\nModifications: {review_text}\n\nCurrent plan:\n{content}"
            }]
        ).content[0].text
        
        plan_path.write_text(updated)
        print("Plan updated based on discoveries")
```

### 5. Multi-Agent Plan Coordination
```python
def create_sub_plan(parent_plan_path: Path, step_num: int, sub_task: str) -> Path:
    """Create a sub-plan for a complex step."""
    parent_dir = parent_plan_path.parent
    sub_plan_path = parent_dir / f"subplan_step{step_num}_{datetime.now().strftime('%H%M%S')}.md"
    
    sub_plan_content = f"""# Sub-Plan: {sub_task}
## Parent: {parent_plan_path.name}
## Parent Step: {step_num}
## Status: IN_PROGRESS

"""
    sub_plan_path.write_text(sub_plan_content)
    return sub_plan_path
```

## Key Commands Reference

```bash
# List all plans in a directory
ls -lt /tmp/plans/*.md | head -20

# Show plan summary (grep for status indicators)
grep -E "^## Status:|^### Step|^- Status:" /tmp/plans/plan_latest.md

# Count completed vs pending steps
grep "Status: DONE" plan.md | wc -l
grep "Status: PENDING" plan.md | wc -l

# Find plans with blockers
grep -l "BLOCKED\|FAILED" /tmp/plans/*.md

# Watch a plan file update in real time
watch -n 2 cat /tmp/plans/plan_latest.md
```

## Common Patterns

### Pattern 1: Claude Code Native Plan
```
Use /plan command in Claude Code, or write a PLAN.md in the project root:
- Claude Code reads PLAN.md automatically
- Checks off items as they're completed
- Updates status after each tool call
```

### Pattern 2: Checkpoint and Resume
```python
def resume_plan(plan_path: Path) -> bool:
    """Resume an interrupted plan from where it left off."""
    content = plan_path.read_text()
    if "Status: IN_PROGRESS" not in content:
        print("No in-progress plan to resume")
        return False
    
    print(f"Resuming plan: {plan_path.name}")
    # Fix any steps stuck IN_PROGRESS (crashed mid-execution)
    content = re.sub(r'- Status: IN_PROGRESS ⟳', '- Status: PENDING ○', content)
    plan_path.write_text(content)
    return execute_plan(plan_path, available_tools)
```

### Pattern 3: Plan as Context Window Bridge
```python
# Before starting a new context, write checkpoint to plan
def write_checkpoint(plan_path: Path, current_state: dict):
    content = plan_path.read_text()
    checkpoint = f"\n## Checkpoint [{datetime.now().isoformat()}]\n"
    for key, value in current_state.items():
        checkpoint += f"- {key}: {value}\n"
    plan_path.write_text(content + checkpoint)
```

## Pitfalls to Avoid

1. **Steps too vague to execute**: "Do the analysis" is not a step — "Run word frequency analysis on corpus.txt and store top-50 terms in analysis/frequencies.json" is. Write steps as if giving instructions to someone who has no context — include file paths, expected outputs, and success criteria.

2. **Not updating the plan file after each step**: The plan is only useful as state if it reflects reality. After every step (success or failure), the file must be updated before continuing. Agents that skip updates create plans that diverge from reality and can't be resumed reliably.

3. **Over-planning before starting**: Don't spend 80% of the task planning 30 steps that will change. Plan 4-6 steps, execute, update based on discoveries, plan the next 4-6 steps. The plan should evolve — it's not a waterfall spec.

## Related Skills

- `prompt-chaining` — Multi-step LLM pipelines (simpler, no file state)
- `agent-loop-patterns` — Agent execution loop patterns
- `executing-plans` — General plan execution skill
- `autonomous-knowledge-system` — Persistent knowledge alongside plans

## GitNexus Index

```json
{
  "skill": "planning-with-files",
  "category": "ai-ml",
  "triggers": ["planning with files", "manus style", "agent planning", "persistent plan", "markdown plan agent", "task planning file"],
  "outputs": ["plan file", "execution loop", "step tracker", "checkpoint"],
  "complexity": "medium",
  "tools": ["python", "anthropic", "markdown", "filesystem"]
}
```
