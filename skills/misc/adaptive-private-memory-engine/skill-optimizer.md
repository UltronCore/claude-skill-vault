# Skill Efficiency Optimizer

**Separate routine for analyzing and improving skill token efficiency.**
**Not personal memory. Not part of APME private data. Safe to publish.**

---

## Purpose

Find and fix token waste in Claude Code skills: unnecessary context loads, bloated prompts, repetitive validation, over-broad triggers, and excessive agent spawning. Improve without weakening safety or judgment quality.

---

## Activation

Run when:
- A skill consistently loads memory or context it doesn't need
- Repetitive validation loops visible in session behavior
- Skill file > 400 lines and triggers frequently
- Trigger description too broad (activating on wrong tasks)
- Explicit: "optimize skills", "audit skill efficiency", "reduce token waste"
- Post-APME setup to tune interactions between APME and other skills

---

## Waste Pattern Checklist

### Context / Memory Loading Waste
- [ ] Skill loads full memory corpus when targeted read would suffice
- [ ] Skill activates on tasks with no personal context need (false positive)
- [ ] Skill reads detail files when summary or index exists
- [ ] Skill loads unrelated memory categories
- [ ] Skill re-reads files already loaded this session
- [ ] Skill loads all preference categories when only one applies

### Validation Chain Waste
- [ ] Same state verified multiple times in one workflow pass
- [ ] Safety check runs after it already passed earlier in session
- [ ] Configuration re-verified on every trigger despite being static
- [ ] Privacy check runs on non-sensitive operations as blanket policy
- [ ] Full audit before minor writes that don't warrant it
- [ ] Unchanged state reread to "confirm" it hasn't changed

### Prompt Structure Waste
- [ ] Same constraint restated more than twice
- [ ] Redundant guardrails covering identical scenarios
- [ ] Verbose narrative where a table would suffice
- [ ] Multiple examples of the same pattern (one good example is enough)
- [ ] Long preamble before actionable content
- [ ] Rules list followed by the same rules as a table
- [ ] Description field summarizes workflow (causes Claude to skip reading skill body)

### Agent Spawning Waste
- [ ] Subagent launched for task completable in < 30 seconds solo
- [ ] Parallel dispatch for tasks that are actually sequential
- [ ] Agent receives full context when targeted excerpt suffices
- [ ] Output synthesis costs more than direct execution would have
- [ ] Agents spawned for single-file reads or writes

### Trigger Breadth Waste (CSO issue)
- [ ] Description includes workflow summary (causes premature task completion)
- [ ] Description triggers on broad terms that match many unrelated tasks
- [ ] Description says "use when executing X" and also describes X's full procedure
- [ ] Trigger matches intent too early before task type is clear

---

## Efficiency Targets

| Skill Type | Target Lines | Rationale |
|---|---|---|
| Always-on / default operating system | < 150 | Loads every session — every line costs |
| Routing / orchestration | < 250 | High trigger frequency |
| Domain skill | < 500 | Triggered by task type |
| Reference / API docs | No limit | Load on explicit demand only |
| Supporting file (not SKILL.md) | No limit | Linked, not auto-loaded |

Skills above target: extract reference content to supporting file and link.

---

## Before / After Fix Patterns

### Problem: Full memory load on non-memory task
```
BEFORE: Skill activates and loads INDEX.md for all tasks
AFTER:  "Only if personal context is needed (see Activation Decision)"
```

### Problem: Description summarizes workflow
```
BEFORE: "Use when building X — dispatches subagents, reviews output, commits result"
AFTER:  "Use when building X and task requires multi-step autonomous execution"
```

### Problem: Redundant guardrails
```
BEFORE:
  Rule 3: Never write to repos.
  Rule 7: Confirm write target is ~/.claude/memory/.
  Rule 9: Do not commit memory files.
  [table row]: Memory write → verify not in repo directory
AFTER:
  One canonical rule: Write path must start with ~/.claude/memory/.
  One place. Referenced, not repeated.
```

### Problem: Re-verification of unchanged state
```
BEFORE: Check INDEX.md exists → check ALIASES.md valid → check memory home exists → then proceed
AFTER:  Trust structure exists (written once on setup). Only verify on write operations.
```

### Problem: Agent spawned for single file
```
BEFORE: Launch subagent to update RESUME.md entry
AFTER:  Direct Edit tool write. No agent. < 10 seconds.
```

### Problem: Narrative where table works
```
BEFORE:
  When the user asks about preferences, load the stable.md file. If that doesn't answer,
  load writing.md. Only load tools.md if the question is specifically about tools.
AFTER:
  | Signal | Load |
  |---|---|
  | Style/communication | preferences/stable.md |
  | Format/tone | preferences/writing.md |
  | Tools/environment | preferences/tools.md |
```

---

## Analysis Protocol

1. List skills that triggered in the last few sessions.
2. For each: note line count, trigger frequency, and any patterns from checklist.
3. Score: frequency × waste patterns found = priority.
4. Fix highest priority first. Apply smallest change that removes the waste.
5. Verify trigger still fires correctly after change.
6. Verify skill behavior is unchanged (same outcomes, less overhead).
7. Note version change in CHANGELOG.md or skill-memory.md.

---

## Output Format

```markdown
## Skill Efficiency Report — [YYYY-MM-DD]

### [skill-name]
**Lines:** [n] | **Trigger frequency:** [estimate] | **Waste found:** [pattern list]
**Fix:** [one-sentence specific action]
**Priority:** [high / medium / low]
---
```

Compact. Action-oriented. Skip skills with no detected waste.

---

## Hard Boundaries

- Do not remove safety logic that is genuinely load-bearing.
- Do not sacrifice judgment quality for speed or brevity.
- Never store personal memory in this output or analysis artifacts.
- Never include personal project names, preferences, or private context in efficiency reports.
- Do not weaken privacy enforcement to reduce token count.
- Do not merge two distinct rules into one ambiguous one just to save lines.

**This routine operates on skill logic only — never on the personal memory corpus.**
