# Claude Skill Vault

A versioned, categorized backup repository for Claude Code skills. Stores every skill as it is created, optimized, replaced, or reorganized — preserving history and making skills browsable by purpose.

## What gets saved

- New skills created in Claude Code
- Updated and optimized versions of existing skills
- Merged, split, and reorganized skills
- Superseded skills (preserved, not deleted)

## What does not get saved

- Personal notes or private data
- API keys, credentials, or secrets
- Personal file paths or identity details
- Project files unrelated to skills

---

## ⭐ Featured Skills

| Skill | Category | Description |
|-------|----------|-------------|
| [brainstorming](skills/orchestration/brainstorming/) | orchestration | Structured creative exploration before any implementation |
| [dispatching-parallel-agents](skills/orchestration/dispatching-parallel-agents/) | orchestration | Run multiple independent investigations simultaneously |
| [systematic-debugging](skills/research/systematic-debugging/) | research | Disciplined approach to any bug or unexpected behavior |
| [writing-plans](skills/orchestration/writing-plans/) | orchestration | Implementation plan creation for multi-step tasks |
| [subagent-driven-development](skills/orchestration/subagent-driven-development/) | orchestration | Delegate tasks to focused subagents with review checkpoints |
| [frontend-design](skills/ui-ux/frontend-design/) | ui-ux | Production-grade frontend interfaces with high design quality |
| [skill-creator](skills/app-usage/skill-creator/) | app-usage | Create, test, and iterate on new Claude Code skills |
| [claude-usage-orchestrator](skills/optimization/claude-usage-orchestrator/) | optimization | Token-efficient task routing — minimal path first |
| [skillguard](skills/app-usage/skillguard/) | app-usage | Protect and manage installed Claude Code skills |

---

## Browse by Category

### 🛠 App Usage
Skills for using and managing Claude Code itself.
→ [Browse app-usage](skills/app-usage/INDEX.md)

### 🎭 Orchestration
Agent coordination, plan execution, and workflow management.
→ [Browse orchestration](skills/orchestration/INDEX.md)

### 🔍 Review
Code review request and response workflows.
→ [Browse review](skills/review/INDEX.md)

### ⚡ Optimization
API cost reduction and performance optimization.
→ [Browse optimization](skills/optimization/INDEX.md)

### 🤖 Automation
CI/CD, linting, testing, and workflow automation.
→ [Browse automation](skills/automation/INDEX.md)

### 🔒 Security
Security hardening, auth, and access control.
→ [Browse security](skills/security/INDEX.md)

### 🎨 UI/UX
Frontend design, components, and user experience.
→ [Browse ui-ux](skills/ui-ux/INDEX.md)

### 🔌 Integrations
Third-party service integrations (Supabase, Sentry, Expo, etc.)
→ [Browse integrations](skills/integrations/INDEX.md)

### 📊 Data Processing
APIs, schemas, validation, and data contracts.
→ [Browse data-processing](skills/data-processing/INDEX.md)

### 🔬 Research
Debugging, investigation, and systematic analysis.
→ [Browse research](skills/research/INDEX.md)

### 📦 Misc
Skills that don't fit a single category.
→ [Browse misc](skills/misc/INDEX.md)

---

## How it works

### Auto-save behavior
Every new skill, optimization, or update is automatically saved to the vault with:
- A versioned snapshot (`versions/v1/`, `versions/v2/`, etc.)
- A human-readable README
- A concise CHANGELOG
- Structured metadata
- Public-safe operational memory

### Versioning
Skills use simple versioning: `v1`, `v2`, `v3`. Prior versions are never deleted. Roll back by reading any `versions/vN/SKILL.md`.

### Lineage tracking
When a skill is replaced, merged, or split, the relationship is recorded in `skills/_registry/lineage.json` and noted in each skill's README and metadata.

### Superseded skills
Old skills aren't deleted — they move to `skills/_obsolete/` with a notice pointing to the newer version.

### Category organization
Skills are organized by primary use case. As the vault grows, categories are reviewed and reorganized when a clearly better structure emerges.

---

## Structure

```
claude-skill-vault/
  skills/
    _registry/      ← registry.json, categories.json, lineage.json, featured.json
    _archive/       ← inactive skills preserved for reference
    _obsolete/      ← skills superseded by newer versions
    _templates/     ← templates for creating new skills
    {category}/     ← active skills by purpose
      {skill-slug}/
        SKILL.md        ← working skill file
        README.md       ← human-friendly description
        CURRENT.md      ← current version snapshot
        metadata.json   ← structured metadata
        CHANGELOG.md    ← version history
        skill-memory.md ← operational notes
        versions/
          v1/SKILL.md   ← baseline snapshot
  scripts/          ← vault-save.sh, vault-import.sh, vault-check.sh, etc.
  state/            ← structure and optimization state
  docs/             ← policies, guidelines, lineage overview
```

---

## Reusing this system

This vault is designed to be adopted by others. See [docs/repository-guidelines.md](docs/repository-guidelines.md) for setup instructions.

Quick start:
```bash
# Import an existing skill
scripts/vault-import.sh my-skill path/to/SKILL.md category-name

# Save a new or updated skill
scripts/vault-save.sh my-skill path/to/SKILL.md category-name

# Run a safety check
scripts/vault-check.sh skills/category/my-skill/

# Refresh registry and indexes after bulk changes
python3 scripts/vault-registry-refresh.py
python3 scripts/vault-index-refresh.py
```

---

## Public safety

All content is reviewed against [docs/public-safety-policy.md](docs/public-safety-policy.md) before committing. No personal data, credentials, or private paths are stored.
