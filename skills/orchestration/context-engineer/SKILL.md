---
name: context-engineer
description: Use when tasks are complex, multi-step, vague, or involve debugging, building, research with execution, or skill creation — any work where wrong scope, missing inputs, or poor framing would cause drift or incorrect output. Activates automatically before execution.
---

# Context Engineer

## Overview

Construct the correct working context before execution. Ensure tasks are performed with the right scope, structure, inputs, and priorities. Prevent context overload, context gaps, and drift.

## Activation

Auto-activate for:
- Complex or multi-step tasks
- Vague or unclear requests
- Skill creation or debugging
- Builds, setups, integrations
- Research plus execution
- Anything where framing determines quality of output

## Five Stages (Internal)

### Stage 1: Task Classification

| Field | Determine |
|-------|-----------|
| Task type | build / fix / analyze / design / research / configure |
| Complexity | single-pass or multi-pass |
| Phases needed | plan → execute → validate |

### Stage 2: Context Selection

**Include:**
- Relevant prior conversation
- Relevant files or screenshots
- Necessary assumptions
- Constraints and dependencies

**Exclude:**
- Unrelated history
- Redundant data
- Noise

### Stage 3: Context Structuring

Organize internally:
1. Objective
2. Inputs
3. Expected outputs
4. Constraints
5. Dependencies
6. Execution steps

### Stage 4: Execution Framing

Decide:
1. Best workflow and output format
2. Sequencing of actions
3. Whether decomposition is needed
4. Whether iteration is required

### Stage 5: Context Control (During Execution)

Throughout the task:
- Prevent drift
- Maintain focus on objective
- Avoid over-expansion
- Keep alignment with original goal

## Context Rules

| Rule | Application |
|------|------------|
| Right context at right time | Load only what is relevant to current phase |
| Do not overload | Exclude noise, history, redundant data |
| Do not under-provide | Include all dependencies and constraints |
| Dynamically adjust | Update context as task evolves |

## Advanced Detection

Automatically detect when:
- Structure improves the outcome → impose structure
- A system, template, or workflow should be created → build one
- Dependencies exist that weren't stated → surface them early
- Long task risks losing alignment → re-anchor to objective

## Failure Prevention

| Avoid | Instead |
|-------|---------|
| Including irrelevant context | Select only what matters |
| Ignoring important context | Pull in files, screenshots, prior state |
| Losing track of objective | Re-anchor at each phase boundary |
| Bloating instructions | Compress, structure, sequence |
| Fragmenting multi-step work | Keep task cohesion across phases |

## Interaction with Other Skills

- Works before `prompt-deepener` expands intent
- Works before `self-healing-execution` begins its loop
- Provides the structured environment both skills operate in

## Success Condition

Claude consistently works with the correct context, producing structured, accurate, and efficient outputs without confusion or drift.
