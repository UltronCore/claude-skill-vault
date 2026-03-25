---
name: adaptive-codex-utilization
description: Use when deciding whether to handle a task in Claude or offload it to Codex via terminal. Activates automatically for execution-heavy tasks (terminal commands, file ops, repo scanning, batch edits, test runs, log parsing, env setup, Obsidian vault operations) and when usage efficiency matters. Routes work to the lightest sufficient tool without sacrificing quality.
---

# Adaptive Codex Utilization

Claude thinks. Codex executes. Choose automatically based on task type and usage pressure.

## Routing Decision

```
Is this reasoning/judgment/architecture?
  YES → Claude handles it

Is this execution/mechanical/terminal-based?
  YES → use Codex

Mixed?
  Claude plans, Codex executes
```

## Usage Pressure Mode

| Pressure | Behavior |
|----------|----------|
| Low (early in cycle) | Claude quality first; Codex for clearly mechanical work |
| Moderate (mid-cycle) | Balance — offload execution-heavy tasks to Codex |
| High (near limit) | Aggressively route to Codex; Claude for reasoning only |
| Reset imminent | Best quality via Claude again |

Do not ask the user which mode. Infer from context (session length, explicit mentions, prior messages).

## Codex Task Types

Route to Codex when the task is:
- Terminal commands, shell scripts
- File read/write/move/organize (including Obsidian vault file ops)
- Repo scanning, grep, directory listing
- Repetitive or batch code edits
- Dependency installs, env setup
- Running tests, lint, typecheck
- Log parsing, structured transformations
- Debugging implementation issues (not architectural ones)

## Claude Task Types

Keep in Claude when:
- Architecture or design decisions
- Ambiguity is high or instructions are unclear
- Output requires judgment, nuance, or synthesis
- Planning what Codex should do next

## Codex Execution Template

When routing to Codex, define clearly:

```
Task: [exact action]
Goal: [expected result]
Scope: [specific files/directories]
Constraints:
  - no unnecessary dependencies
  - no unrelated edits
  - preserve architecture and style
  - no secret exposure
Checks: [tests/lint/typecheck if available]
```

Then invoke:
```bash
codex "<task description>"
# or with scope:
codex -d /path/to/scope "<task description>"
```

## Validation

After Codex runs:
- Confirm result matches goal
- Check for obvious breakage
- Return concise summary: what was done, outcome, any issues

## Failover

Codex fails → retry once with tighter scope → if still failing, resolve in Claude → return to Codex for remaining execution.

## Efficiency Rules

- Don't use Codex for trivial one-liners (Claude handles inline)
- Don't use Claude for repetitive mechanical execution (Codex wins)
- Keep outputs concise — no unnecessary explanation in either tool
- `~/.agents/skills/` is Codex's skill directory — this skill is installed there too
