# APME Memory Schema — Templates and Schemas

All templates here. No personal data. Safe to publish.

---

## Project Entry — Active (`projects/active/[name].md`)

```markdown
# [Project Name]
**Status:** active
**Path:** [local path]
**Last worked:** [YYYY-MM-DD]
**Aliases:** [comma-separated keywords → this file]

## What It Is
[One to two sentences. What it produces or solves.]

## Current State
[What is built. What is in progress.]

## Next Step
[Exact next action — specific enough to act on immediately]

## Key Decisions
| Decision | Rationale |
|---|---|
| [choice] | [why, one sentence] |

## References
[Key paths, tools, or external links — only if safe]

## Resume Notes
[Anything needed to resume cold that isn't captured above]
```

---

## Project Entry — Paused (`projects/paused/[name].md`)

```markdown
# [Project Name]
**Status:** paused
**Paused:** [YYYY-MM-DD]
**Path:** [local path]
**Aliases:** [keywords]

## What It Is
[One sentence.]

## Where It Was Left
[Last completed step]

## Resume From
[Exact starting point for next session]

## Blockers / Reasons Paused
[Why it stopped]

## Key Decisions Made
| Decision | Rationale |
|---|---|

## References
[Safe paths or links]
```

---

## Project Entry — Archive (`projects/archive/[name].md`)

Archive entries are compact. Outcome + key decisions only. No full detail.

```markdown
# [Project Name] — Archived
**Completed / Abandoned:** [YYYY-MM-DD]
**Outcome:** [one sentence — what was delivered or why abandoned]

## Key Decisions
| Decision | Rationale |
|---|---|

## Lessons
[One to two sentences — what to carry forward]

## References
[Any links or paths still useful]
```

---

## Lesson Entry (`lessons/[topic].md`)

For surprises, failures, anti-patterns, and hard-won insights.

```markdown
# Lesson: [Topic]
**Date:** [YYYY-MM-DD]
**Context:** [which project or situation]
**Applies to:** [general / specific domain / tool]

## What Happened
[Brief — what was unexpected or went wrong]

## What to Do Instead
[Concrete correction or better approach]

## Anti-Pattern
[The thing to avoid — stated clearly]

## Carries Forward To
[Related projects or future situations where this applies]
```

---

## Pattern Entry (`patterns/[name].md`)

For proven reusable approaches and techniques.

```markdown
# Pattern: [Name]
**Aliases:** [keywords]
**Last used:** [YYYY-MM-DD]
**Applies to:** [context, tool, or domain]

## When to Use
[Trigger conditions — when does this pattern fit]

## Steps
1. [step]
2. [step]
3. [step]

## Variations
| Condition | Adjustment |
|---|---|
| [when] | [how steps change] |

## When NOT to Use
[Counter-indications]

## Notes
[Edge cases, gotchas, or refinements]
```

---

## Preference Entry (`preferences/[type].md`)

```markdown
# [Category] Preferences
**Last updated:** [YYYY-MM-DD]

## Core Preferences
| Preference | Value / Description |
|---|---|
| [name] | [value] |

## When These Apply
[Scope, context, or default conditions]

## Override Conditions
[When to deviate — user instruction, specific task type, edge case]
```

---

## Decision Entry (`decisions/[topic].md`)

```markdown
# Decision: [Topic]
**Date:** [YYYY-MM-DD]
**Status:** [standing / superseded by X / revisit after Y]

## Choice
[What was decided — one sentence]

## Rationale
[Why — two to four sentences max]

## Alternatives Considered
| Option | Why Not Chosen |
|---|---|
| [alternative] | [reason] |

## Conditions for Revisit
[What would justify reconsidering this]
```

---

## Workflow Entry (`workflows/[name].md`)

```markdown
# Workflow: [Name]
**Aliases:** [keywords]
**Last used:** [YYYY-MM-DD]
**Applies to:** [project, tool, or general context]

## Steps
1. [step — actionable]
2. [step]
3. [step]

## Variations
| Situation | Variation |
|---|---|
| [condition] | [adjusted step] |

## Notes
[Edge cases, caveats, reminders]
```

---

## RESUME.md Entry

```markdown
## Resume: [Task Name] — [YYYY-MM-DD]
**Objective:** [one sentence]
**Status:** [what is complete]
**Next:** [exact next action — immediately actionable]
**Blockers:** [none / list]
**Key refs:** [safe file paths or decision anchors]
**Confidence:** [high / medium / low]
**Stale after:** [date or trigger event]
**Sensitivity:** [low / medium / high]
```

Rules:
- Max 10 lines per entry
- Max 20 entries in RESUME.md total
- Archive on completion, delete when stale
- Never store credentials, tokens, full transcripts

---

## ALIASES.md Schema

```markdown
# Alias Map
_Last updated: [YYYY-MM-DD]_

## Project Aliases
| Keyword / Alias | Target File |
|---|---|
| [keyword] | projects/active/[name].md |
| [nickname] | projects/paused/[name].md |

## Workflow Aliases
| Keyword | Target |
|---|---|
| [phrase] | workflows/[name].md |

## Pattern Aliases
| Keyword | Target |
|---|---|
| [phrase] | patterns/[name].md |

## Preference Aliases
| Keyword | Target |
|---|---|
| [phrase] | preferences/[type].md |

## Decision / Lesson Aliases
| Keyword | Target |
|---|---|
| [topic] | decisions/[topic].md |
| [topic] | lessons/[topic].md |
```

Maintenance: Verify paths after any file move. Rebuild when lookups fail 2+ times.

---

## INDEX.md Schema

```markdown
# Memory Index
_Last updated: [YYYY-MM-DD] | Files: [n] | Stale flags: [n]_

## Active Projects
- [[Name]](projects/active/name.md) — [status, one line]

## Paused
- [[Name]](projects/paused/name.md) — paused [date]

## Preferences
- [stable](preferences/stable.md) — [tag]
- [writing](preferences/writing.md) — [tag]
- [tools](preferences/tools.md) — [tag]

## Workflows
- [[name]](workflows/name.md) — [tag]

## Patterns
- [[name]](patterns/name.md) — [tag]

## Lessons
- [[topic]](lessons/topic.md) — [tag]

## Decisions
- [[topic]](decisions/topic.md) — [date]

## Active Resumes
- [task] — RESUME.md

## Maintenance Notes
[Flags, repairs needed, or compression scheduled]
```

Hard limit: 60 lines. Pointers and tags only — no detail inline.

---

## Session Cache Entry (`.cache/[date].md`)

Ephemeral. Session-scoped only. Never sensitive.

```markdown
# Session Cache — [YYYY-MM-DD]
## Resolved Routes
| Trigger | Resolved Path | Loaded at |
|---|---|---|
| [keyword/alias] | ~/.claude/memory/[path] | [HH:MM] |

## Loaded This Session
- [file paths, for dedup guard]

## Invalidation
Clear when: session ends, source file modified, explicit clear
```

---

## Sensitivity Classification

| Level | Examples | Handling Rule |
|-------|----------|--------------|
| **Low** | Project names, tool prefs, workflow patterns | Standard memory rules |
| **Medium** | Personal opinions, work dynamics, relationship context | Store intent/pattern — not raw detail |
| **High** | Health, finances, credentials, legal, identity | Elevated threshold — minimum storage, pattern not detail |

**Default: classify one level higher when unsure.**

---

## Stale Marker Format

When an entry needs review but isn't wrong yet:

```
[stale-check: YYYY-MM-DD — reason]
```

Add inline to the relevant field. Triggers lightweight maintenance scan.
