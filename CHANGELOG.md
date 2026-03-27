# Changelog

All notable changes to the Claude Skill Vault are documented here.

Format: [Semantic Versioning](https://semver.org/). Categories: `feat` (new skills/features), `improve` (skill updates), `refactor` (reorganization), `chore` (maintenance), `docs` (documentation).

---

## [1.0.0] — 2026-03-27

**First official public release.** Establishes the vault as a polished, publicly adoptable Claude Code skill system.

### What's included at this baseline

- **75 active skills** across 15 categories, fully organized and indexed
- **49 archived skills** preserved in `_archive/` (plugin duplicates, consolidated sub-skills)
- **Skill versioning system** — every skill has version snapshots in `versions/vN/SKILL.md`
- **Central registry** — `skills/_registry/registry.json` with full metadata for all skills
- **Lineage tracking** — `skills/_registry/lineage.json` records merges, splits, and supersessions
- **Vault scripts** — `vault-save.sh`, `vault-import.sh`, `vault-check.sh`, `vault-registry-refresh.py`, `vault-index-refresh.py`
- **Public safety policy** — all skills reviewed for credentials, private paths, and personal data before commit
- **Documentation** — `docs/` covers repository guidelines, optimization policy, lineage overview, and public safety policy
- **GitHub Actions** — automatic release workflow wired to `VERSION` file changes

### Skill categories at v1.0.0

| Category | Active Skills | Purpose |
|----------|--------------|---------|
| app-usage | 3 | Claude Code management, skill creation, memory |
| automation | 9 | CI/CD, scaffolding, testing, linting |
| business | 3 | Domain, invoicing, meeting analysis |
| data-processing | 2 | API contracts, env config |
| integrations | 6 | Supabase, Expo, Sentry, vector DB, observability |
| marketing | 31 | Content, SEO, ads, CRO, growth |
| misc | 1 | Overflow/transitional |
| optimization | 4 | LLM routing, performance, server actions |
| orchestration | 4 | Agent loops, RAG, ultra-lovable, subagent patterns |
| research | 0 | (Skills archived to external plugin) |
| review | 2 | Skill review, vault-push-guardian |
| security | 6 | Auth, CSP, RLS, guardrails, hardening |
| ui-ux | 5 | Forms, Tailwind, shadcn, markdown editor |
| writing | 2 | Doc co-authoring, resume generation |

### Infrastructure changes (this release)

- Added `VERSION` file as canonical version source of truth
- Added `LICENSE` (MIT)
- Added `CHANGELOG.md` (this file)
- Added `.github/workflows/release.yml` — automatic GitHub Releases on `VERSION` change
- Added `.github/release.yml` — release notes category configuration
- Added `CONTRIBUTING.md`
- Added `.github/ISSUE_TEMPLATE/` — skill request and bug report templates
- Added `.github/pull_request_template.md`
- Overhauled `README.md` for public credibility and adoption

---

## How future releases work

Bump the `VERSION` file on `main` → the release workflow fires automatically → a new GitHub Release is created with auto-generated notes from commits since the last tag.

To release manually: use the `Release` workflow dispatch from the GitHub Actions tab with a version input.

---

<!-- Links -->
[1.0.0]: https://github.com/UltronCore/claude-skill-vault/releases/tag/v1.0.0
