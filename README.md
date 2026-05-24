# Claude Skill Vault

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/UltronCore/claude-skill-vault?color=blue)](https://github.com/UltronCore/claude-skill-vault/releases)
[![Skills](https://img.shields.io/badge/active%20skills-632-brightgreen)](skills/)
[![Platform](https://img.shields.io/badge/platform-Claude%20Code-orange)](https://claude.ai/code)
[![Maintained](https://img.shields.io/badge/maintained-yes-green)](https://github.com/UltronCore/claude-skill-vault/commits/main)

A versioned, categorized backup and distribution vault for [Claude Code](https://claude.ai/code) skills — **632 active skills** across 27 categories, with full version history, lineage tracking, and auto-save tooling.

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
| [marketing](skills/marketing/) | 65 | Content strategy, SEO, ads, CRO, email, pricing, growth |
| [integrations](skills/integrations/) | 38 | Firecrawl, Temporal, MCP, Supabase, Gmail, Linear, YouTube, deep research |
| [ai-ml](skills/ai-ml/) | 59 | LLM frameworks, RAG, vector DBs, AI agents, fine-tuning, embeddings, semantic search |
| [automation](skills/automation/) | 45 | CI/CD, scaffolding, linting, testing, git workflows, Vercel, Remotion |
| [security](skills/security/) | 34 | Auth, CSP, RLS, SAST, fuzzing, YARA rules, supply chain, prompt injection defense |
| [backend](skills/backend/) | 22 | Go, gRPC, GraphQL, Redis, Postgres, Kafka, auth, API design, architecture patterns |
| [ui-ux](skills/ui-ux/) | 36 | SwiftUI, Tailwind/shadcn, D3.js, React patterns, accessibility, forms |
| [app-usage](skills/app-usage/) | 23 | Claude Code management, NotebookLM, Apple Docs, iOS simulator, SkillGuard |
| [devops](skills/devops/) | 15 | Kubernetes, platform engineering, chaos, blue-green, tracing, service mesh |
| [engineering-practices](skills/engineering-practices/) | 31 | Code review, architecture, testing strategies, refactoring patterns |
| [writing](skills/writing/) | 22 | Office docs, prompt deepening, research writing, engineering blog, Tufte reports |
| [orchestration](skills/orchestration/) | 23 | Agent loops, RAG pipelines, memory engines, context engineering |
| [frontend](skills/frontend/) | 21 | React Server Components, Next.js perf, micro-frontends, TypeScript patterns |
| [productivity](skills/productivity/) | 16 | GitNexus tools, planning, multi-agent orchestration, knowledge graphs |
| [cloud-devops](skills/cloud-devops/) | 20 | Docker, AWS, Azure, Kubernetes, Crossplane, OpenTofu, Pulumi, infrastructure patterns |
| [ios-swift](skills/ios-swift/) | 16 | iOS development, Swift patterns, Xcode tooling |
| [ios-mobile](skills/ios-mobile/) | 5 | Android, Flutter, mobile CI/CD, SwiftUI data flow |
| [data-engineering](skills/data-engineering/) | 17 | ETL pipelines, data modeling, Spark, dbt, data quality, Dagster, Meltano |
| [data](skills/data/) | 8 | ClickHouse, Elasticsearch, Ray, dbt analytics, data quality |
| [optimization](skills/optimization/) | 14 | LLM routing, performance budgets, server actions, SwiftUI perf |
| [product-business](skills/product-business/) | 9 | Product strategy, roadmaps, user research, metrics, OKRs |
| [review](skills/review/) | 11 | Skill review, vault-push guardian, public release review, issue triage |
| [compliance](skills/compliance/) | 5 | Regulatory compliance, privacy, audit trails, policy enforcement |
| [business](skills/business/) | 13 | Domain brainstorming, invoicing, meeting insights, PRD to issues |
| [misc](skills/misc/) | 8 | Code sandbox, Excalidraw diagrams, skill portfolio, Codex utilization |
| [data-processing](skills/data-processing/) | 10 | API contracts, Zod validation, env config, LLM eval |
| [research](skills/research/) | 1 | Web research and data gathering |
| [_archive](skills/_archive/) | 108 | Preserved: superseded, consolidated, or plugin-managed |

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
| [rag-pipeline](skills/orchestration/rag-pipeline/) | orchestration | Full RAG pipeline — ingestion, indexing, retrieval, multiple search backends |
| [tdd](skills/automation/tdd/) | automation | Test-driven development workflow — red/green/refactor with Claude |
| [security-scanner](skills/security/security-scanner/) | security | Automated security scanning and vulnerability detection |
| [cloudflare-pages-autopush](skills/automation/cloudflare-pages-autopush/) | automation | Auto-commit and push Cloudflare Pages projects — on demand and proactively |
| [multi-repo-push-workflow](skills/automation/multi-repo-push-workflow/) | automation | Git push discipline across multiple related repos (client, vault, template) |

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

| Level | What it tracks | Where |
|-------|---------------|-------|
| **Skill-level** | Iterations of a single skill (v1, v2, v3...) | `versions/` inside each skill folder |
| **Repo-level** | Official vault releases (1.0.0, 1.2.0...) | `VERSION` file + GitHub Releases |

### Lineage tracking

When a skill is replaced, merged, or split, the relationship is recorded in `skills/_registry/lineage.json` and in each affected skill's README and metadata. You can always trace where a skill came from or what replaced it.

### Superseded skills

Old skills are never deleted — they move to `skills/_archive/` with a notice pointing to the current version. Roll back to any previous version by reading `versions/vN/SKILL.md`.

---

## Quick start

### Use an individual skill

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

1. Update `VERSION` to the next semantic version (e.g., `1.3.0`)
2. Commit and push to `main`
3. GitHub Actions automatically creates a tagged release

Manual release: use the **Release** workflow dispatch from the [Actions tab](https://github.com/UltronCore/claude-skill-vault/actions).

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

---

## What does not get saved

- Personal notes, private data, or credential-adjacent content
- API keys, tokens, or secrets
- Personal file paths or client names
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
