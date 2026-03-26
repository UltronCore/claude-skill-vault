---
name: adaptive-private-memory-engine
description: Use when recalling personal context, resuming prior work, looking up project state, writing to private memory, saving resumable state, or maintaining the memory system. Routes selectively — loads only the memory subset relevant to the current task. Never reads all memory.
---

# Adaptive Private Memory Engine (APME)

## Core Rules (Non-Negotiable)

1. Load only what the current task needs. Never read all memory.
2. Update only when continuity would otherwise be lost.
3. Personal memory never goes in skills, repos, CLAUDE.md body, commits, PRs, or shared artifacts.
4. The skill stays publishable and persona-free.
5. Token efficiency is a primary design constraint, not an afterthought.

---

## Memory Home

All private memory lives at `~/.claude/memory/` — outside repos, skill vault, and any tracked content.

```
~/.claude/memory/
  INDEX.md          ← Fast routing index (≤50 lines, pointers only)
  ALIASES.md        ← Keyword/alias → file path mapping
  RESUME.md         ← Resumable state entries
  preferences/
    stable.md       ← Communication style, tool defaults, general prefs
    writing.md      ← Tone, format, voice preferences
    tools.md        ← Environment, CLI, app preferences
  projects/
    active/         ← One file per active project
    paused/         ← Paused with resume notes
    archive/        ← Completed or abandoned
  workflows/        ← Recurring multi-step patterns
  decisions/        ← Important choices with rationale
  .cache/           ← Session routing cache (clearable, never sensitive)
```

**Path safety rule:** Before any write, confirm target is within `~/.claude/memory/`. If uncertain — skip the write.

---

## Activation Decision

```
Does this task require personal context?
  NO  → Skip memory entirely. Proceed with task.
  YES → What type?
          Project alias triggered      → ALIASES.md → direct to project file
          "Resume", "where were we"    → RESUME.md
          Preference / style question  → preferences/[relevant].md
          New info worth saving        → Classify first (see Write Policy)
          Unknown                      → INDEX.md for routing
          Maintenance signal           → Check scale/drift (see Maintenance)
```

**False positive suppression:** Do NOT activate memory for:
- Pure factual / technical questions with no personal context
- Casual conversation
- Tasks explicitly scoped to current context only
- Questions answered by the current codebase or file

---

## Staged Retrieval Protocol

Follow in order. Stop as soon as sufficient context is assembled.

1. Decide if memory is needed at all. If not — stop here.
2. Classify the task: project, preference, workflow, decision, or resume.
3. Check ALIASES.md for a direct route. If found — load only that target.
4. If no alias hit, load INDEX.md. Use it for routing only.
5. Load the relevant category summary file.
6. Open a specific detail file only if summary is insufficient.
7. Check `.cache/` for routing results from this session. Reuse if valid.
8. Do not re-read any file already loaded this session.
9. Return compact working context. Exclude everything unrelated.
10. Stop.

**Never jump to step 6 without trying steps 3–5 first.**

---

## Trigger Taxonomy

| Trigger Type | Example Signals | Routing Action |
|---|---|---|
| **Project alias** | Known project name, nickname, abbreviation | ALIASES.md → `projects/active/[name].md` |
| **Paused work** | "where we left off", "continue from", "we were working on" | `RESUME.md` |
| **Preference recall** | "my writing style", "how I like X formatted", "my usual approach" | `preferences/[type].md` |
| **Workflow** | "the pattern we use for X", "how we usually do Y" | `workflows/[name].md` |
| **Decision recall** | "why did we choose X", "what was the reason for Y" | `decisions/[topic].md` |
| **Save for later** | "pause here", "note this", "save this state" | Write to `RESUME.md` |
| **End of meaningful task** | Major step complete, continuity risk detected | Targeted write if warranted |
| **Maintenance signal** | Memory feels stale, bloated, broken links, aliases failing | Lightweight scan first |
| **Sensitivity flag** | Health, finances, credentials, relationship details | Elevated caution threshold |

**Trigger precision:** Require at least one clear signal. Ambiguous single-word references do not auto-trigger. Ask or proceed without memory rather than guess.

---

## Memory Write Policy

**Classify before writing. This takes 5 seconds and prevents bloat.**

| Classification | Write? | Where |
|---|---|---|
| Durable long-term value | Yes | `preferences/`, `projects/`, `decisions/` |
| Useful working memory | Yes (compact) | Summary section of relevant category file |
| Resumable state | Yes | `RESUME.md` entry |
| Uncertain / unconfirmed | Label only | Inline `[unconfirmed: YYYY-MM-DD]` |
| Trivial exchange | No | Discard |
| Sensitive / personal detail | High threshold | Intent/pattern only, not raw detail |

**Writing rules:**
- Update existing entries; do not duplicate.
- Active projects: next step + brief status only. No transcripts.
- Decisions: one-sentence rationale. Not reasoning logs.
- Prefer compact table updates over paragraph additions.
- Use `[unconfirmed]` labels for provisional information.
- Write at continuity risk points — not after every exchange.
- Sensitive material: store the pattern, not the raw personal data.

---

## Resumable State Format

Use when work may be interrupted or needs a handoff. Entries stay under 10 lines.

```markdown
## Resume: [Task Name] — [YYYY-MM-DD]
**Objective:** [one sentence]
**Status:** [what is done]
**Next:** [exact next action]
**Blockers:** [list or "none"]
**Key refs:** [safe file paths or decision links, if any]
**Confidence:** [high / medium / low]
**Stale after:** [date or event trigger]
**Sensitivity:** [low / medium / high]
```

**Archive when complete. Delete when stale. Never let RESUME.md exceed 20 entries.**

---

## INDEX.md Contract

The INDEX.md must stay compact and fast to load.

```markdown
# Memory Index — [YYYY-MM-DD]

## Active Projects
- [Name](projects/active/name.md) — [one-line status]

## Paused Projects
- [Name](projects/paused/name.md) — [paused since date]

## Preferences
- [stable](preferences/stable.md) — [tag]
- [writing](preferences/writing.md) — [tag]
- [tools](preferences/tools.md) — [tag]

## Active Resumes
- [task name] — see RESUME.md

## Aliases
See ALIASES.md for full trigger map.

## Maintenance
Last checked: [date] | File count: [n] | Stale flags: [n]
```

**Hard limit: 50 lines. If exceeded — compress or archive.**

---

## Privacy Enforcement

**Tiered model. Not constant full audits.**

| Event | Check Required |
|---|---|
| Routine memory read | None — trust staged retrieval |
| Memory write | Confirm write path is `~/.claude/memory/` |
| Session with sensitive data touched | Targeted leak scan before ending |
| Generating shareable artifact | Explicit check: no personal memory in output |
| Structural memory changes | Full privacy review |
| Repo commit or PR creation | Verify no memory content in staged files |

**Hard privacy rules:**
1. Memory never written into any repo directory.
2. Memory never in `~/claude-skill-vault/` or any skill file.
3. CLAUDE.md contains routing instructions and operational rules only — never personal data.
4. Generated docs, exports, summaries: scan for personal content before output.
5. If a workflow would expose personal memory — reroute or refuse. Never silently proceed.
6. Skill files (including this one) remain publishable with zero personal content.

**Fail closed on privacy. On ambiguity — skip the write, never guess.**

---

## Maintenance Schedule

**Default: lightweight and event-based. Heavy: only when triggered.**

| Signal | Action |
|---|---|
| INDEX.md > 50 lines | Compress summaries, archive stale entries |
| Any memory file > 200 lines | Split or compress into subcategories |
| Alias lookup fails 2+ times | Repair alias map |
| Duplicate entries detected | Merge compact |
| RESUME.md entry > 30 days old | Archive or delete |
| "Clean up memory" requested | Full lightweight scan |
| Post-major-project | Archive completed project, update INDEX |

**Lightweight maintenance** (< 5 min equivalent): fix aliases, compress one file, update INDEX.

**Heavy maintenance** (full dedup, taxonomy optimization) only when:
- Memory home exceeds 40 files
- Multiple stale markers present
- Explicit request
- Agent-assisted optimization is clearly cost-effective

**Do not run maintenance on every session. Do not reread all files to check unchanged state.**

---

## Agent Orchestration

Optional. Use only when it materially reduces cost or improves quality.

| Task | Agent appropriate? | Notes |
|---|---|---|
| Single file update | No | Direct write |
| Alias map optimization | Maybe | Only if map is large and broken |
| Full deduplication scan | Yes | Bounded parallel read across files |
| Privacy review before publish | Yes | Single focused agent, no raw personal data |
| Taxonomy cleanup | Yes (occasional) | When drift is significant |
| Routine INDEX update | No | Direct write |

**Agent constraints:**
- Agents receive no raw sensitive personal content.
- Outputs are compact, action-oriented, and applied by Claude.
- Claude writes all final memory changes.
- No agent externalizes or broadly restates personal memory.
- Simple tasks — no agent dispatch.

---

## Quick Reference

```
Need memory at all?         → Activation Decision flowchart
Known project or alias?     → ALIASES.md → direct load
No direct route?            → INDEX.md → category summary → detail if needed
Writing memory?             → Classify first. Update compact.
Resuming work?              → RESUME.md → load entry
Ending meaningful task?     → Assess continuity risk. Write if needed.
Maintenance needed?         → Lightweight first, check triggers
Privacy concern?            → Tiered check. Fail closed.
Session routing cache?      → `.cache/` — reuse if valid, clear freely
```

---

*Templates and schemas: see `memory-schema.md`*
*Skill efficiency optimization: see `skill-optimizer.md`*
