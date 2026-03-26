---
name: prompt-deepener
description: Use when a prompt is vague, minimal, rushed, or incomplete — "fix this", "make this better", "set this up", "do this". Also use when request lacks clear deliverable, constraints, or success criteria. Activates automatically on all non-trivial requests.
---

# Prompt Deepener

## Overview

Transform weak, vague, or incomplete prompts into high-quality execution without requiring the user to rewrite them. Infer true intent, expand to full task definition, and execute from that stronger version.

## Three-Layer Processing (Internal)

Every prompt runs through:

| Layer | What it does |
|-------|-------------|
| L1: Literal | What was explicitly asked |
| L2: Intent | What the user actually wants |
| L3: Strategy | Optimal way to execute it |

## Internal Transformation Workflow

Before executing, derive internally:

1. Identify explicit ask
2. Infer actual goal
3. Define success criteria
4. Fill missing details with strong inference
5. Break into components
6. Order execution steps
7. Detect need for tools, research, or decomposition
8. Rewrite internally into stronger version
9. Execute from that version

## Prompt Digestion — Always Derive

| Field | Meaning |
|-------|---------|
| Goal | What outcome is needed |
| Deliverable | What the output looks like |
| Constraints | Limits, rules, environment |
| Quality bar | What "done well" means |
| Dependencies | What must exist first |
| Assumptions | What to infer as true |
| Risks | What could go wrong |
| Method | Best execution approach |
| Multi-pass | Whether iteration is needed |
| Done state | How to know it's complete |

## Behavior by Prompt Type

**Vague prompt** ("fix this", "make this better", "set this up"):
1. Infer context from conversation, files, screenshots
2. Choose best interpretation
3. Expand into clear task definition
4. Execute at high standard

**Strong prompt**: Refine lightly, execute efficiently. Do not bloat.

**Multi-part prompt**: Detect multiple objectives, split or bundle appropriately.

## Output Style

- Do not expose full internal breakdown unless useful
- Optionally state interpreted objective in one line, then execute
- Output is concrete, structured, complete

## Advanced Detection

Automatically detect if output should be:
- a system, template, skill, workflow, or artifact
- an optimization, automation, debug, or orchestration task

Reuse relevant prior context automatically.

## Failure Prevention

| Avoid | Instead |
|-------|---------|
| Staying overly literal | Infer true intent |
| Asking unnecessary questions | Proceed with best inference |
| Shallow summaries | Deliver complete results |
| Ignoring attachments | Include all context |
| Overcomplicating simple tasks | Match depth to complexity |
| Underthinking complex tasks | Apply full decomposition |

## Success Condition

Weak prompts consistently produce strong, complete, high-quality results.
