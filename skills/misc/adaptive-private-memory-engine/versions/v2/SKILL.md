---
name: adaptive-private-memory-engine
description: Use when recalling personal context, resuming prior work, looking up project state or preferences, writing to private memory, saving resumable state, or maintaining the memory system. Routes selectively — loads the minimum relevant subset. Never reads all memory. Activates on project names, aliases, "resume", "where were we", style questions, and explicit save/recall requests.
---

# Adaptive Private Memory Engine (APME) v2

## Non-Negotiable Rules

1. **Load only what the task needs.** Never read all memory.
2. **Update only at continuity risk.** Not after every exchange.
3. **Memory never enters skills, repos, commits, PRs, or shared artifacts.**
4. **Skill stays publishable.** Zero personal content here.
5. **Token efficiency is a primary constraint** — not an afterthought.
6. **Fail closed on privacy.** On ambiguity, skip the write.

---

## Memory Home Structure

```
~/.claude/memory/
  INDEX.md            ← Routing index (hard cap: 60 lines, pointers only)
  ALIASES.md          ← Keyword/alias → file path map
  RESUME.md           ← Active resumable state (max 20 entries)
  preferences/
    stable.md         ← Communication style, general approach
    writing.md        ← Tone, format, voice
    tools.md          ← Environment, CLI, app preferences
  projects/
    active/           ← One file per active project
    paused/           ← Paused with resume notes
    archive/          ← Completed/abandoned (compact summaries only)
  workflows/          ← Recurring multi-step patterns
  decisions/          ← Important choices with rationale
  lessons/            ← Lessons learned, failure patterns, hard-won insights
  patterns/           ← Reusable approaches, templates, proven techniques
  .cache/             ← Session routing cache (ephemeral, never sensitive)
```

**Write path rule:** Before any write, verify target starts with `~/.claude/memory/`. If uncertain — skip the write.

---

## Activation Decision

Run this before touching any memory file. Stop at the first match.

```
Is personal context needed for this task?
  NO  → Skip memory. Proceed.
  YES → Identify signal type:

  Signal: known project name / alias        → ALIASES.md → project file (direct)
  Signal: "resume", "continue", "left off"  → RESUME.md
  Signal: preference / style question       → preferences/[type].md
  Signal: "why did we", "what was the"      → decisions/ or lessons/
  Signal: recurring pattern / "how we do"   → workflows/ or patterns/
  Signal: saving / pausing work             → Classify → write to RESUME.md
  Signal: new info worth keeping            → Classify (see Write Policy)
  Signal: maintenance flag                  → Check scale/drift triggers
  Signal: unknown route                     → INDEX.md for routing
```

**False positive suppression — do NOT activate for:**
- Pure technical questions with no personal context
- Casual conversation or one-liners
- Tasks fully answered by current file/codebase
- Generic "how do I" questions with no personal history

---

## Staged Retrieval Protocol

Follow in order. Stop as soon as sufficient context exists.

| Step | Action | Stop condition |
|------|--------|----------------|
| 1 | Need memory at all? | No → stop immediately |
| 2 | Classify task type | Determines which branch to follow |
| 3 | Check `.cache/` for this session's resolved routes | Hit → use cached path, skip 4–6 |
| 4 | Check `ALIASES.md` for direct route | Hit → load target only, skip 5–6 |
| 5 | Load `INDEX.md` for routing only | Identifies category and file |
| 6 | Load category summary file | Sufficient → stop |
| 7 | Open specific detail file | Only if summary insufficient |
| 8 | Assemble compact working context | Exclude all unrelated memory |
| 9 | Cache resolved route in `.cache/` | For reuse within this session |
| 10 | Stop | |

**Never read detail (step 7) before attempting summary (step 6).**
**Never re-read a file already loaded this session unless source changed.**
**Never load unrelated categories even if memory exists there.**

---

## Trigger Taxonomy

All 10 trigger types. Require at least one clear signal before activating.

| Type | Signal Examples | Action |
|------|----------------|--------|
| **Project alias** | Known project name, nickname, path reference | `ALIASES.md` → `projects/[status]/[name].md` |
| **Paused work** | "resume", "continue", "left off", "where were we" | `RESUME.md` → load matching entry |
| **Preference** | "my style", "how I like X", "my usual approach to Y" | `preferences/[type].md` |
| **Workflow** | "the pattern for X", "how we usually Y", "our process" | `workflows/[name].md` |
| **Topic / domain** | Recurring subject area the user has history with | `lessons/[topic].md` or `patterns/[topic].md` |
| **Decision recall** | "why did we choose X", "what was the reason for Y" | `decisions/[topic].md` |
| **Save / resume later** | "pause here", "note this", "save for later", "I'll come back" | Write to `RESUME.md` |
| **End of meaningful task** | Major step complete, continuity risk detected | Classify → targeted write if durable value |
| **Low continuity risk** | Task ending, work was minor, no resume value | Skip write — no memory update |
| **Stale maintenance** | Alias fails, index outdated, file > 200 lines, 30+ day old resumes | Lightweight maintenance only |
| **Sensitivity flag** | Health, finances, credentials, legal, relationships | Elevate caution — store pattern not detail |

**Precision rule:** Single ambiguous words do not trigger. Require phrase-level signal or explicit request.

---

## Memory Taxonomy

Nine categories. Use the right one — don't force fit.

| Category | What Goes Here | Location |
|----------|---------------|----------|
| **Preferences** | Communication style, tool defaults, format preferences | `preferences/` |
| **Active projects** | Status, next step, key decisions, resume notes | `projects/active/` |
| **Paused projects** | What was in progress, where to resume | `projects/paused/` |
| **Archive** | Compact completed project summaries, outcomes | `projects/archive/` |
| **Workflows** | Recurring multi-step patterns with variations | `workflows/` |
| **Decisions** | Choices made with rationale and revisit conditions | `decisions/` |
| **Lessons learned** | Failures, surprises, hard-won insights, anti-patterns | `lessons/` |
| **Patterns** | Reusable approaches, proven techniques, templates | `patterns/` |
| **Resumable state** | Short-lived handoff notes, not long transcripts | `RESUME.md` |

**Archive** is compact — outcome + key decisions only, not full project detail.
**Lessons** are discovery notes — what was surprising, what failed, what to avoid.
**Patterns** are prescriptive — what works reliably and how to apply it.

---

## Memory Write Policy

Classify before writing. Prevents bloat and drift.

| Classification | Write? | Target | Notes |
|----------------|--------|--------|-------|
| Durable long-term value | Yes | preferences/, projects/, decisions/, lessons/, patterns/ | Full entry |
| Useful working memory | Yes (compact) | Summary section of relevant file | Table row preferred |
| Resumable state | Yes | RESUME.md | Max 10 lines |
| Uncertain / provisional | Label only | Inline `[unconfirmed: YYYY-MM-DD]` | No separate file |
| Trivial chatter | No | Discard | |
| Sensitive / personal detail | High threshold | Pattern/intent only — no raw detail | Store minimum |

**Writing rules:**
- Update existing entries. Do not duplicate.
- Active projects: next step + brief status only. No transcripts.
- Decisions: one-sentence rationale. Not reasoning logs.
- Lessons: one paragraph max. What happened, what to do differently.
- Patterns: steps + key variations. Not exhaustive docs.
- Use `[unconfirmed: DATE]` for anything uncertain.
- Write at continuity risk — not mechanically after every turn.
- Sensitive: store the pattern or intent, never raw personal detail.
- After any write: update INDEX.md if new file created.

---

## Session Cache Rules

`.cache/` stores resolved routing for the current session only.

**Write to cache:** When a route is resolved (alias → file, or INDEX lookup → file path).
**Read from cache:** At step 3 of retrieval — before any other file read.
**Cache entry format:** `[trigger keyword] → [resolved file path] — [timestamp]`
**Invalidate:** If source file was modified this session, or session ends.
**Never cache:** Sensitive lookups, write operations, or anything containing personal detail.
**Clear freely:** Cache can be deleted at any time with no data loss.

---

## Resumable State Format

Compact handoff note. Not a transcript.

```markdown
## Resume: [Task Name] — [YYYY-MM-DD]
**Objective:** [one sentence — what is being accomplished]
**Status:** [what is complete]
**Next:** [exact next action — specific enough to act on immediately]
**Blockers:** [none / list]
**Key refs:** [file paths or decision anchors — safe to note]
**Confidence:** [high / medium / low]
**Stale after:** [date or event, e.g. "after PR merged"]
**Sensitivity:** [low / medium / high]
```

**Hard rules:**
- Max 10 lines per entry
- Max 20 entries total in RESUME.md
- Archive on completion
- Delete when stale
- Never store credentials, keys, or full session transcripts

---

## INDEX.md Contract

Fast routing index. Pointers only — no detail inline.

```markdown
# Memory Index — [YYYY-MM-DD]
_Files: [n] | Stale flags: [n]_

## Active Projects
- [Name](projects/active/name.md) — [one-line status]

## Paused
- [Name](projects/paused/name.md) — paused [date]

## Preferences
- [stable](preferences/stable.md), [writing](preferences/writing.md), [tools](preferences/tools.md)

## Workflows / Patterns / Lessons
- [name](workflows/name.md) | [name](patterns/name.md) | [topic](lessons/topic.md)

## Active Resumes
- [task name] — RESUME.md

## Maintenance
Last checked: [date] | Action needed: [none / describe]
```

**Hard limit: 60 lines.** If exceeded — compress summaries, archive stale entries.

---

## Privacy Enforcement

Tiered model. Not constant full audits.

| Event | Check Required |
|-------|---------------|
| Routine memory read | None — trust staged retrieval |
| Memory write | Verify path starts with `~/.claude/memory/` |
| Sensitive category touched | Confirm output contains no raw personal detail |
| Session ending with sensitive data in context | Targeted leak scan: check last write, check any generated text |
| Creating shareable artifact (doc, PR, summary, export) | Explicit scan: no personal memory in output |
| Structural memory changes (rename, reorganize, merge) | Full privacy review |
| Commit or push operation nearby | Verify no memory files in staged changes |

**Hard privacy rules — no exceptions:**
1. Memory never written into repo directories.
2. Memory never in `~/claude-skill-vault/` or any skill file.
3. `CLAUDE.md` contains routing rules only — no personal data corpus.
4. Generated summaries, docs, exports: verify clean before output.
5. If workflow risks personal memory exposure — reroute or refuse. Never silently proceed.
6. This skill file contains zero personal content. Safe to publish as-is.

---

## Maintenance Schedule

Lightweight and event-based by default. Heavy only when triggered.

### Lightweight triggers (fix immediately, < 2 min)
| Signal | Action |
|--------|--------|
| Alias lookup fails 2+ times | Repair alias map, verify file paths |
| RESUME.md entry > 30 days old | Archive or delete entry |
| INDEX.md approaching 60 lines | Compress, remove stale pointers |
| Duplicate entry found | Merge compact, keep latest |
| Post-major-project completion | Archive project, update INDEX |

### Moderate triggers (next available, < 10 min)
| Signal | Action |
|--------|--------|
| Any memory file > 200 lines | Split into subcategory or compress |
| Fragmented low-value entries (3+ files, < 5 lines each) | Merge into one file |
| Frequently accessed summary missing from INDEX | Promote to INDEX entry |
| Lessons/patterns not linked from relevant projects | Add cross-references |

### Heavy maintenance (explicit request or threshold breach)
| Trigger | Action |
|---------|--------|
| Memory home > 40 files | Full dedup, taxonomy audit, routing optimization |
| Multiple stale flags across files | Full lightweight scan all files |
| Routing taking > 3 steps consistently | Rebuild ALIASES.md from usage patterns |
| Explicit "clean up memory" or "optimize memory" | Full review + agent-assisted if large |

**Never run heavy maintenance on routine sessions.**
**Never reread all memory to verify unchanged state.**

---

## Agent Orchestration

Optional. Use only when it materially reduces cost or improves quality.

**When agents help:**

| Task | Use agent? | Constraint |
|------|-----------|-----------|
| Single file update or write | No | Direct operation |
| Alias map rebuild (large, broken) | Maybe | Bounded read, no sensitive data |
| Full deduplication across 10+ files | Yes | Parallel bounded read |
| Privacy review before shareable output | Yes | Single focused agent |
| Taxonomy cleanup (significant drift) | Yes | Agent proposes, Claude writes |
| Routine INDEX update | No | Direct write |
| Session cache update | No | Direct write |
| Stale entry archive (1–3 entries) | No | Direct operation |

**Eight agent constraints — all apply:**
1. Agent use is optional. Only when it saves real effort or cost.
2. Agents must not increase token load for trivial tasks.
3. Claude is the final authority on all memory writes, privacy checks, and structural changes.
4. Sensitive memory is minimized or excluded before passing to any agent.
5. No agent may externalize, restate, or broadly summarize personal memory.
6. Parallel agents only when tasks are independent and parallelism reduces total cost.
7. Simple tasks — no agent fanout. One operation = direct execution.
8. Agent outputs are compact and action-oriented. Claude applies them.

---

## Quick Reference

```
Need memory?            → Activation Decision
Known alias/project?    → ALIASES.md (or .cache/) → direct load
Unknown route?          → INDEX.md → category file → detail if needed
Writing memory?         → Classify first → update existing compact
Resuming work?          → RESUME.md → load matching entry
Ending task?            → Continuity risk? Yes → write. No → skip.
Maintenance?            → Lightweight by default. Check triggers.
Privacy check?          → Tiered. Fail closed. Skip write on doubt.
Session cache?          → .cache/ — reuse routes, clear freely, never sensitive
```

---

*Templates and entry schemas → `memory-schema.md`*
*Skill token efficiency analysis → `skill-optimizer.md`*
