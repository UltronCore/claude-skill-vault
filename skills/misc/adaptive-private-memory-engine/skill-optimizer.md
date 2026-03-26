# Skill Efficiency Optimizer

**Separate routine for skill token efficiency analysis.**
**Not personal memory. Not part of APME private data. Safe to publish.**

---

## Purpose

Review Claude Code skills for token waste, unnecessary context loading, bloated prompts, repetitive validation chains, and over-eager agent spawning. Produce targeted improvements without weakening safety or judgment.

## Activation

Run when:
- A skill consistently causes unnecessary memory reads or context loads
- Repetitive validation loops detected in session behavior
- Skill file is large (> 400 lines) and often triggered
- Explicit request: "optimize skills", "audit skill efficiency", "reduce token usage"
- Post-APME setup to calibrate interaction between APME and other loaded skills

---

## Waste Pattern Checklist

### Context Loading Waste
- [ ] Skill loads full memory corpus when a targeted read suffices
- [ ] Skill triggers memory reads on non-memory tasks (false positive activation)
- [ ] Skill reads detail files when a summary or index exists
- [ ] Skill loads unrelated memory categories
- [ ] Skill re-reads files already loaded this session

### Validation Chain Waste
- [ ] Same state checked multiple times in one pass
- [ ] Safety check runs after it already passed earlier in the same workflow
- [ ] Skill re-verifies unchanged configuration on every trigger
- [ ] Privacy check runs on non-sensitive operations as a blanket policy
- [ ] Skill runs full audit before minor writes

### Prompt Structure Waste
- [ ] Same constraint stated more than twice in skill content
- [ ] Redundant guardrails that cover identical scenarios
- [ ] Verbose narrative where a table or code block would suffice
- [ ] Multiple examples of the same pattern (one good example is enough)
- [ ] Long preamble before actionable content

### Agent Spawning Waste
- [ ] Subagent launched for tasks completable in < 30 seconds solo
- [ ] Parallel dispatch for tasks that are actually sequential
- [ ] Agent receives full context when a targeted excerpt suffices
- [ ] Agent output requires expensive synthesis when direct execution was faster
- [ ] Agents spawned for single-file reads or writes

---

## Efficiency Targets

| Skill Type | Target Max Lines | Notes |
|---|---|---|
| Always-on / default operating system | < 150 lines | Loads every session |
| Routing / orchestration | < 250 lines | Frequent trigger |
| Domain skill | < 500 lines | Triggered by task |
| Reference / template | No limit | Load on demand only |
| Supporting file (not SKILL.md) | No limit | Load by explicit reference |

Skills above target should be compressed or split into primary + supporting files.

---

## Analysis Protocol

1. List skills that triggered in recent sessions.
2. For each flagged skill: count lines, identify trigger frequency, note any patterns from checklist.
3. Map loading cost against value delivered.
4. Prioritize: highest load frequency × highest waste score first.
5. Apply smallest fix that removes the waste pattern.
6. Verify trigger behavior is unchanged after optimization.
7. Update skill version note or changelog entry.

---

## Fix Patterns

| Waste Finding | Fix |
|---|---|
| Full memory load on non-memory task | Add activation guard: "only if personal context needed" |
| Repeated state validation | Add "already verified this session" short-circuit |
| Bloated prompt | Compress to table + code block format |
| Redundant guardrails | Merge into one canonical rule |
| Unnecessary agent spawn | Convert to inline direct operation |
| Broad context scan | Replace with targeted file path + index lookup |
| Always-on skill too large | Extract reference content to supporting file; link from SKILL.md |
| Example overload | Keep best single example; remove duplicates |
| Narrative where structure works | Convert to table |

---

## Output Format

When producing a skill efficiency report:

```markdown
## Skill Efficiency Report — [YYYY-MM-DD]

### [skill-name]
**Lines:** [n] | **Load frequency:** [per session estimate] | **Waste patterns found:** [list]
**Recommendation:** [specific action — one sentence]
**Priority:** [high / medium / low]
---
```

Keep reports compact. Action-oriented. Skip skills with no detected waste.

---

## Boundaries

**Do not:**
- Remove safety logic that is genuinely load-bearing
- Optimize away judgment in favor of mechanical speed
- Store personal memory data in this analysis output
- Include personal project names, preferences, or private context in efficiency reports
- Weaken privacy enforcement to save tokens

**This routine touches skill logic only — never the personal memory corpus.**
