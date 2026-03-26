# APME Memory Schema Templates

Templates and schemas for structured memory entries.
**No personal data. Safe to publish as part of the skill.**

---

## Project Entry (projects/active/ or projects/paused/)

```markdown
# [Project Name]
**Status:** [active / paused / winding-down]
**Path:** [local path]
**Last worked:** [YYYY-MM-DD]
**Aliases:** [comma-separated keywords that trigger this file]

## What It Is
[One to two sentences. What this project produces or solves.]

## Current State
[What is built and working. What is in progress.]

## Next Step
[Exact next action — specific enough to act on immediately]

## Key Decisions
| Decision | Rationale |
|---|---|
| [what was chosen] | [why, one sentence] |

## Important References
[Key file paths, URLs, or external resources — only if safe to note]

## Resume Notes
[Any extra context needed to pick this back up cold]
```

---

## Preference Entry (preferences/[type].md)

```markdown
# [Category] Preferences
**Last updated:** [YYYY-MM-DD]

## Core Preferences
| Preference | Value / Description |
|---|---|
| [preference name] | [value or short description] |

## When These Apply
[Context, scope, or exceptions]

## Override Conditions
[When to deviate — explicit user instruction, specific task type]
```

---

## Decision Entry (decisions/)

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
[What would trigger reconsidering this]
```

---

## Workflow Entry (workflows/)

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
[Edge cases, caveats, or reminders]
```

---

## RESUME.md Entry Format

```markdown
## Resume: [Task Name] — [YYYY-MM-DD]
**Objective:** [one sentence]
**Status:** [what is done]
**Next:** [exact next action]
**Blockers:** [list or "none"]
**Key refs:** [safe paths or decision links]
**Confidence:** [high / medium / low]
**Stale after:** [date or event]
**Sensitivity:** [low / medium / high]
```

**Rules:**
- Maximum 10 lines per entry
- Archive when complete
- Delete when stale or superseded
- Maximum 20 entries in RESUME.md at any time

---

## ALIASES.md Format

```markdown
# Alias Map
_Last updated: [YYYY-MM-DD]_

## Project Aliases
| Keyword / Alias | Target File |
|---|---|
| [keyword] | projects/active/[name].md |
| [nickname] | projects/paused/[name].md |

## Workflow Aliases
| Keyword | Target File |
|---|---|
| [phrase] | workflows/[name].md |

## Preference Aliases
| Keyword | Target File |
|---|---|
| [phrase] | preferences/[type].md |

## Decision Aliases
| Keyword | Target File |
|---|---|
| [topic] | decisions/[topic].md |
```

**Maintenance:** Rebuild alias map when lookups fail. Verify paths are valid after file moves.

---

## INDEX.md Format

```markdown
# Memory Index
_Last updated: [YYYY-MM-DD] | Files: [n] | Stale flags: [n]_

## Active Projects
- [[Name]](projects/active/name.md) — [status]

## Paused Projects
- [[Name]](projects/paused/name.md) — paused [date]

## Preferences
- [stable](preferences/stable.md) — [brief tag]
- [writing](preferences/writing.md) — [brief tag]
- [tools](preferences/tools.md) — [brief tag]

## Workflows
- [[name]](workflows/name.md) — [brief tag]

## Decisions
- [[topic]](decisions/topic.md) — [date]

## Active Resumes
- [task] — see RESUME.md

## Maintenance Notes
[Stale entries, needed repairs, or optimization notes]
```

**Hard limit: 50 lines. Routing pointers only — no detail inline.**

---

## Session Cache Entry (.cache/)

```markdown
# Cache: [session-date]
**Valid for:** current session only
**Route resolved:** [alias/keyword] → [file path]
**Loaded files:** [list]
**Notes:** [routing shortcuts or pre-resolved lookups]
```

**Clear freely. Never store sensitive content in cache. Cache is routing optimization only.**

---

## Sensitivity Classification Guide

| Level | Examples | Handling |
|---|---|---|
| **Low** | Project names, tool preferences, workflow patterns | Standard memory rules |
| **Medium** | Personal opinions, relationship context, work dynamics | Store intent/pattern only |
| **High** | Health, finances, credentials, legal, identity | Elevated threshold; minimal storage; pattern not detail |

**When in doubt, classify one level higher.**
