---
name: skill-portfolio-architect
description: Perform a full audit and architectural redesign of the Claude skill library using parallel subagents. Use when the skill library needs cleanup, redundancy removal, merging overlapping skills, deprecating plugin duplicates, recategorizing skills, or improving overall skill architecture. Also use proactively when skill count exceeds 60 active skills (80% of healthy capacity of 75). Triggers on: skill audit, portfolio redesign, skill consolidation, skill library review, skill inventory, deprecate skill, merge skills, skill health check, vault cleanup, skill bloat.
---

# Skill Portfolio Architect

Audit, redesign, and optimize the complete Claude skill library using parallel subagents. Run proactively when the vault grows past threshold.

## When to Run

**Run immediately if any are true:**
- Active vault skills > 60 (80% of healthy capacity ceiling of 75)
- New skills added since last audit > 10
- Duplicate plugin skills detected in vault
- `misc/` or catch-all categories exist
- Locally installed skills missing from vault backup

**Check current state:**
```bash
# Active skill count
find ~/claude-skill-vault/skills -name "SKILL.md" | grep -v "_archive\|/versions/" | wc -l

# Installed but not backed up
comm -23 \
  <(ls ~/.claude/skills/ | sort) \
  <(find ~/claude-skill-vault/skills -mindepth 2 -maxdepth 2 -type d | grep -v "_archive\|_registry\|_templates\|versions" | xargs -I{} basename {} | sort)

# Categories with content
ls ~/claude-skill-vault/skills/ | grep -v "^_"
```

If count ≤ 48 and no orphans and no catch-all categories: vault is healthy. No action needed.

---

## Execution Strategy

This skill runs in **two parallel phases** then a **sequential implementation phase**.

### Spawn Phase 1 + 2 in parallel

Dispatch one subagent per category for inventory, while simultaneously dispatching an orphan-checker subagent.

**Per-category inventory subagent prompt:**
```
Read all SKILL.md files in ~/claude-skill-vault/skills/<category>/ (excluding _archive and versions/).
For each skill output a table row: | name | lines | function (1 sentence) | overlap_risk (none/low/high) |
Also flag:
- Plugin duplicates: name matches any skill in the superpowers or skill-creator plugin
- Sub-skills: clearly a subset of another skill in same or different category
- Domain-specific: contains worldbuilding, app-specific paths, or project names
- Catch-all: category is 'misc' or similar
Return the table and a summary: "N skills, M flags"
```

**Orphan-checker subagent prompt:**
```
Compare locally installed skills vs vault backup:
  installed: ls ~/.claude/skills/
  vault:     find ~/claude-skill-vault/skills -mindepth 2 -maxdepth 2 -type d | grep -v "_archive|_registry|_templates|versions" | xargs -I{} basename {}
List any skill directories present in ~/.claude/skills/ but absent from vault.
Also list any skill present in vault but NOT installed locally (informational only).
```

Spawn all category subagents + orphan-checker in the same message (parallel).

---

### Phase 3: Decision Analysis (sequential, after Phase 1+2 complete)

Aggregate all subagent reports. Apply decision framework:

| Decision | Criteria |
|----------|---------|
| **KEEP** | Focused, unique, not covered by a plugin |
| **DEPRECATE** | Exact or near-exact plugin duplicate (superpowers:*, skill-creator:*) |
| **MERGE** | Two skills cover the same problem domain |
| **CONSOLIDATE** | 3+ sub-skills of one tool (e.g., firecrawl-scrape + firecrawl-search + ...) → merge into parent |
| **RECATEGORIZE** | Skill is in wrong/catch-all category |
| **IMPORT** | Locally installed skill missing from vault |
| **ARCHIVE** | Superseded, low quality, or project-specific with no generalizable value |

**Plugin duplicate rule:** Any vault skill with the same name/function as a currently loaded plugin is always DEPRECATE. Never maintain a local copy of a plugin skill.

---

### Phase 4: Implementation (parallel subagents where independent)

Group actions by type and dispatch in parallel:

**Archive subagent** (handles all DEPRECATE + ARCHIVE decisions):
```
Archive these vault skills by moving to _archive/:
  mv ~/claude-skill-vault/skills/<category>/<slug>/ ~/claude-skill-vault/skills/_archive/
List: [list of skills to archive]
```

**Merge subagent** (handles each MERGE/CONSOLIDATE group):
```
Merge these skills into one:
  Sources: [list skill paths]
  Target: ~/claude-skill-vault/skills/<category>/<merged-slug>/SKILL.md
Read all source skills. Write a consolidated SKILL.md that:
- Combines frontmatter descriptions (all trigger terms)
- Uses sections for each source skill's unique content
- Removes cross-references between merged skills
Then archive the source skills.
```

**Import subagent** (handles IMPORT decisions):
```
Import these locally installed skills to vault:
  [list: slug → category]
For each: bash ~/claude-skill-vault/scripts/vault-save.sh <slug> ~/.claude/skills/<slug>/SKILL.md <category>
```

**Recategorize subagent** (handles RECATEGORIZE decisions):
```
Move these vault skills to correct categories:
  [list: current-path → target-category]
mv ~/claude-skill-vault/skills/<old-category>/<slug>/ ~/claude-skill-vault/skills/<new-category>/
```

Dispatch all four subagents in the same message. They operate on different directories so there is no conflict.

---

### Phase 5: Finalize (sequential, after all Phase 4 agents complete)

```bash
cd ~/claude-skill-vault
python3 scripts/vault-registry-refresh.py
python3 scripts/vault-index-refresh.py
git add -A
git commit -m "refactor: skill portfolio audit — archive N, merge M, import K"
git push
```

---

## Output Report

Always produce after completion:

```markdown
# Skill Portfolio Audit — YYYY-MM-DD

## Health Check
- Active skills before: N | after: N
- Archived: N (plugin duplicates: N, consolidated: N, superseded: N)
- Merged: N pairs → N skills
- Imported: N (local-only → vault)
- Recategorized: N

## Actions Taken
| Skill | Decision | Reason |
|-------|---------|--------|

## Active Vault State
| Category | Count | Skills |
|----------|-------|--------|

## Next Audit Trigger
Run again when active skills > 60 or > 10 new skills added.
```

---

## Rules Going Forward

1. No vault copy of any skill that a loaded plugin already provides
2. No `misc/` catch-all category — every skill belongs in a real category
3. Every skill in `~/.claude/skills/` must be backed up in vault
4. firecrawl and similar multi-command tools stay as one consolidated skill
5. Maximum 75 active skills before automatic audit is triggered
