---
name: skill-portfolio-architect
description: Perform a full audit and architectural redesign of the Claude skill library. Use when the skill library needs cleanup, redundancy removal, merging overlapping skills, deprecating plugin duplicates, or improving the overall skill architecture. Triggers on: skill audit, portfolio redesign, skill consolidation, skill library review, skill inventory, deprecate skill, merge skills.
---

# Skill Portfolio Architect

Audit, redesign, and optimize the complete Claude skill library. This is a meta-skill that operates on the skill vault itself.

## Assessment Before Starting

1. **Scope** — personal vault only (`~/claude-skill-vault/`) or also installed skills (`~/.claude/skills/`)?
2. **Plugin skills** — never redesign externally-maintained plugin skills (superpowers bundle, firecrawl, skill-creator, frontend-design). Treat as fixed.
3. **Goal** — full audit and redesign, or targeted fix?

## Phase 1: Full Inventory

Read every SKILL.md in the vault:
```bash
ls ~/claude-skill-vault/skills/**/ | grep -v _
```

For each skill, capture:
- Name, category, approximate line count
- Core function (one sentence)
- Domain specificity (generic vs. project-specific)
- Relationships to other skills

Batch reads in parallel (6-8 at a time) to minimize time.

## Phase 2: Functional Clustering

Group skills by what they actually do, not by their folder:

| Cluster | Examples |
|---------|---------|
| AI/LLM API | claude-api, structured-output, llm-routing |
| Web stack | nextjs-scaffold, server-actions, revalidation |
| Security | auth-checker, csp-generator, rls-policies |
| Testing/CI | testing-stack, playwright, eslint-husky |
| Observability | sentry-otel, llm-observability |
| Agent/Orchestration | agent-loops, rag, vector-db |
| UI/Forms | form-generator, tailwind-setup, ui-auditor |
| Meta/Skills | writing-skills, skill-reviewer |

## Phase 3: Decision Framework

For each skill, choose one:

**A — KEEP AS-IS**: Focused, high-quality, no overlap
**B — DEPRECATE**: Exact or near-exact plugin duplicate
**C — MERGE**: Two skills covering overlapping ground → consolidate
**D — REWRITE**: Good concept but too domain-specific (worldbuilding refs, app-specific paths)
**E — ARCHIVE**: Low quality, rarely triggered, or superseded

### Plugin duplicate detection

Skills that are duplicates of active plugins are always decision B:
- superpowers:* skills → DEPRECATE
- skill-creator:skill-creator → DEPRECATE
- Any skill with identical name/function to a loaded plugin

## Phase 4: Architecture Design

Design the target state:
- Which categories to keep/rename
- What merged skills look like (combined frontmatter, merged content)
- Which domain-specific references to generalize
- New cross-reference links between related skills

Document as a table:
| Skill | Decision | Notes |
|-------|---------|-------|

## Phase 5: Implementation

Execute changes in this order:

### 5a: Archive plugin duplicates
```bash
mkdir -p ~/claude-skill-vault/skills/_archive
mv ~/claude-skill-vault/skills/<category>/<slug>/ ~/claude-skill-vault/skills/_archive/
```

### 5b: Merges
- Read both source skills
- Write new merged SKILL.md with combined content
- Archive source skills
- Update vault with `scripts/vault-save.sh`

### 5c: Rewrites
- Read original skill
- Identify domain-specific examples/paths to generalize
- Rewrite with generic examples
- Save to vault

### 5d: Register and commit
```bash
cd ~/claude-skill-vault
python3 scripts/vault-registry-refresh.py
python3 scripts/vault-index-refresh.py
git add -A
git commit -m "refactor: skill portfolio redesign - archive N duplicates, merge M skills"
git push
```

## Output Report

Always produce a structured report:

```markdown
# Skill Portfolio Audit Report — [Date]

## Inventory (N total skills)
[Table: name | category | lines | decision]

## Overlap Analysis
[List overlapping skill pairs and why]

## Decisions Made
- Deprecated (N): [list] — reason: plugin duplicates
- Archived (N): [list] — reason: superseded
- Merged (N pairs): [list]
- Rewritten (N): [list]
- Kept (N): [list]

## New Architecture Map
[Category tree with all surviving skills]

## Token Efficiency Impact
- Before: N skills, ~X total lines
- After: N skills, ~X total lines
- Reduction: X%

## Future Rules
1. No new skill if a loaded plugin already covers it
2. Compact reference skills (< 150 lines) preferred over long procedural guides
3. Generic examples only — no app-specific references
4. Cross-reference related skills with "Related skills:" footer
```
