# Claude Skill Vault

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/UltronCore/claude-skill-vault?color=blue)](https://github.com/UltronCore/claude-skill-vault/releases)
[![Skills](https://img.shields.io/badge/active%20skills-131-brightgreen)](skills/)
[![Platform](https://img.shields.io/badge/platform-Claude%20Code-orange)](https://claude.ai/code)
[![Maintained](https://img.shields.io/badge/maintained-yes-green)](https://github.com/UltronCore/claude-skill-vault/commits/main)

A versioned, categorized backup and distribution vault for [Claude Code](https://claude.ai/code) skills — **131 active skills** across 13 categories, with full version history, lineage tracking, and auto-save tooling.

---

## Why it exists

Claude Code skills live in `~/.claude/skills/`. They accumulate, get updated, and occasionally get replaced — but there is no built-in persistence or version history. This vault solves that:

- **Every skill change is preserved** — baseline, iterations, and current version all stored
- **Skills are browsable by purpose** — not just a flat dump of files
- **Public-safe by policy** — credentials, private paths, and personal data never committed
- **Reproducible** — clone and import to any machine in minutes

This is not a plugin marketplace. It is a structured, actively maintained personal skill vault that happens to be public so others can adopt the system or borrow individual skills.

---

## Who it's for

- **Claude Code users** who want version-controlled skill management
- **Developers** who build custom skills and want a backup and publishing workflow
- **Teams** who want a shared, auditable skill library
- **Anyone** who wants to adopt this system for their own vault

---

## What's included

| Category | Count | What's in it |
|----------|-------|--------------|
| [marketing](skills/marketing/) | 30 | Content strategy, SEO, ads, CRO, email, pricing, growth |
| [integrations](skills/integrations/) | 17 | Firecrawl (8 skills), Temporal, MCP builder, Supabase, Expo, Sentry, vector DB, LLM observability |
| [automation](skills/automation/) | 18 | CI/CD, scaffolding, linting, testing, file automation, git workflows |
| [ui-ux](skills/ui-ux/) | 11 | SwiftUI (5 skills), Tailwind/shadcn, forms, accessibility, visual creation |
| [orchestration](skills/orchestration/) | 9 | Agent loops, RAG pipelines, memory engines, context engineering |
| [writing](skills/writing/) | 8 | Office docs (DOCX/PDF/PPTX), prompt deepening, research writing, resume |
| [app-usage](skills/app-usage/) | 8 | Claude Code management, NotebookLM, Apple Docs, iOS simulator, SkillGuard |
| [security](skills/security/) | 7 | Auth, CSP, RLS policies, output guardrails, hardening, security scanning |
| [optimization](skills/optimization/) | 6 | LLM routing, performance budgets, server actions, SwiftUI perf audit |
| [review](skills/review/) | 5 | Skill review, vault-push guardian, public release review, issue triage |
| [misc](skills/misc/) | 4 | Code sandbox, Excalidraw diagrams, skill portfolio architect, Codex utilization |
| [data-processing](skills/data-processing/) | 4 | API contracts, Zod validation, env config, LLM eval |
| [business](skills/business/) | 4 | Domain brainstorming, invoicing, meeting insights, PRD to issues |
| [_archive](skills/_archive/) | 51 | Preserved: superseded, consolidated, or plugin-managed |

---

## ⭐ Featured Skills

| Skill | Category | What it does |
|-------|----------|--------------|
| [adaptive-private-memory-engine](skills/orchestration/adaptive-private-memory-engine/) | orchestration | Privacy-hardened Claude memory — selective loading, zero personal data in shared artifacts |
| [vault-push-guardian](skills/review/vault-push-guardian/) | review | Block git commits that contain credentials or private data before they leave your machine |
| [skillguard](skills/app-usage/skillguard/) | app-usage | Protect and manage installed Claude Code skills — prevent accidental overwrites |
| [ultra-lovable-orchestrator](skills/orchestration/ultra-lovable-orchestrator/) | orchestration | Full-stack autonomous app generation with multi-agent coordination |
| [output-guardrails](skills/security/output-guardrails/) | security | Prevent sensitive data leakage from LLM outputs |
| [context-engineer](skills/orchestration/context-engineer/) | orchestration | Build and maintain structured context windows for long-running Claude sessions |
| [rag-pipeline](skills/orchestration/rag-pipeline/) | orchestration | Full RAG pipeline setup — ingestion, indexing, retrieval, search backends |
| [tdd](skills/automation/tdd/) | automation | Test-driven development workflow — red/green/refactor with Claude |
| [security-scanner](skills/security/security-scanner/) | security | Automated security scanning and vulnerability detection in codebases |

> Many powerful skills (brainstorming, systematic-debugging, writing-plans, etc.) are maintained in external plugins and live in `_archive/` here as reference copies. See [SOURCE-MAP.md](SOURCE-MAP.md) for origins.

---

## How it works

### Skill structure

Every skill in the vault follows this layout:

```
skills/{category}/{skill-slug}/
  SKILL.md          ← the working skill file (install this one)
  README.md         ← human-friendly description and usage notes
  CURRENT.md        ← snapshot of current version and state
  metadata.json     ← structured metadata (category, version, tags, public_safe)
  CHANGELOG.md      ← version history for this skill
  skill-memory.md   ← operational notes Claude uses when running this skill
  versions/
    v1/SKILL.md     ← baseline snapshot
    v2/SKILL.md     ← first update
    ...             ← full history, never deleted
```

### Versioning: two levels

This vault uses two independent versioning systems:

| Level | What it tracks | Where |
|-------|---------------|-------|
| **Skill-level** | Iterations of a single skill (v1, v2, v3...) | `versions/` inside each skill folder |
| **Repo-level** | Official vault releases (1.0.0, 1.1.0...) | `VERSION` file + GitHub Releases |

Skill versions track incremental improvements to one skill. Repo versions represent meaningful milestones — new capability areas, infrastructure changes, or significant skill additions.

### Lineage tracking

When a skill is replaced, merged, or split, the relationship is recorded in `skills/_registry/lineage.json` and in each affected skill's README and metadata. You can always trace where a skill came from or what replaced it.

### Superseded skills

Old skills are never deleted — they move to `skills/_archive/` with a notice pointing to the current version. Roll back to any previous version by reading `versions/vN/SKILL.md`.

### Category organization

Skills are organized by primary use case. Categories are reviewed when any single category exceeds 15 skills or when a clearly better structure emerges. Current state is documented in `state/structure-state.json`.

---

## Quick start

### Use an individual skill

Browse the vault, find a skill you want, and copy `SKILL.md` to your Claude Code skills directory:

```bash
# Install the vault-push-guardian skill
cp skills/review/vault-push-guardian/SKILL.md ~/.claude/skills/vault-push-guardian.md
```

Then invoke it in Claude Code with `/vault-push-guardian` or by describing the task.

### Clone and bootstrap your own vault

```bash
git clone https://github.com/UltronCore/claude-skill-vault.git my-skill-vault
cd my-skill-vault

# Import an existing skill from your machine
scripts/vault-import.sh my-skill ~/.claude/skills/my-skill.md category-name

# Save a new or updated skill
scripts/vault-save.sh my-skill ~/.claude/skills/my-skill.md category-name

# Safety check before committing
scripts/vault-check.sh skills/category/my-skill/

# Rebuild registry and indexes after bulk changes
python3 scripts/vault-registry-refresh.py
python3 scripts/vault-index-refresh.py
```

See [docs/repository-guidelines.md](docs/repository-guidelines.md) for the full setup guide.

### Browse and explore

- [MASTER-INDEX.md](MASTER-INDEX.md) — complete skill index with descriptions
- [ROUTING-GUIDE.md](ROUTING-GUIDE.md) — how to find the right skill for a task
- [SOURCE-MAP.md](SOURCE-MAP.md) — where each skill came from

---

## Vault scripts

| Script | Purpose |
|--------|---------|
| `scripts/vault-save.sh` | Save a new or updated skill with automatic versioning |
| `scripts/vault-import.sh` | Import a skill for the first time as a v1 baseline |
| `scripts/vault-check.sh` | Safety-check a skill folder before committing |
| `scripts/vault-registry-refresh.py` | Rebuild `skills/_registry/registry.json` |
| `scripts/vault-index-refresh.py` | Rebuild all category `INDEX.md` files |

---

## How releases work

This vault uses automated GitHub Releases tied to the `VERSION` file:

1. Update `VERSION` to the next semantic version (e.g., `1.3.0`)
2. Commit and push to `main`
3. GitHub Actions automatically creates a tagged release with notes generated from commits since the last tag

Manual release: use the **Release** workflow dispatch from the [Actions tab](https://github.com/UltronCore/claude-skill-vault/actions) with a version input.

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

---

## What does not get saved

- Personal notes, private data, or credential-adjacent content
- API keys, tokens, or secrets of any kind
- Personal file paths or identity details
- Project files unrelated to skills

All content is reviewed against [docs/public-safety-policy.md](docs/public-safety-policy.md) before committing.

---

## Repository structure

```
claude-skill-vault/
  skills/
    _registry/       ← registry.json, categories.json, lineage.json, featured.json
    _archive/        ← inactive skills preserved for reference
    _templates/      ← scaffold template for new skills
    {category}/      ← active skills organized by use case
      {skill-slug}/
        SKILL.md     ← install this
        versions/    ← full version history (never deleted)
  scripts/           ← vault management scripts
  docs/              ← policies and guidelines
  state/             ← structure and optimization state
  .github/
    workflows/       ← release automation
  VERSION            ← canonical repo version (semver)
  CHANGELOG.md       ← release history
  MASTER-INDEX.md    ← complete skill index
  ROUTING-GUIDE.md   ← skill routing and discovery guide
  SOURCE-MAP.md      ← skill origin tracking
```

---

## Contributing

This is a personal vault that is intentionally public. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, request skills, or adapt this system for your own use.

---

## License

[MIT](LICENSE) — skills and tooling are yours to use, adapt, and redistribute.
