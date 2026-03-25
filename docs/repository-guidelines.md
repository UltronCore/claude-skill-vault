# Repository Guidelines

This document explains how to use and adopt the Claude Skill Vault system.

## What this repository is

A versioned, categorized backup vault for Claude Code skills. It stores skills as they are created, updated, optimized, or replaced — preserving history and making skills browsable by purpose.

## Adopting this system

To use this vault system yourself:

1. Fork or clone this repository
2. Update `skills/_registry/registry.json` to reflect your own skills
3. Clear `skills/` category folders and import your own skills
4. Run `scripts/vault-import.sh <skill-slug> <source-path> <category>` to import a skill
5. Connect to your own GitHub repository via `gh repo create` or `git remote add`

## Directory structure

```
skills/
  _registry/     — central registry, categories, lineage, featured list
  _archive/      — skills removed from active use but preserved
  _obsolete/     — skills superseded by newer versions
  _templates/    — templates for creating new skills
  {category}/    — active skills organized by purpose
scripts/         — automation helpers
state/           — repository state tracking
docs/            — documentation
```

## Adding a new skill

```bash
scripts/vault-save.sh <slug> <source-path> <category>
```

This creates the skill folder, writes all required files, snapshots v1, and stages changes for commit.

## Updating an existing skill

Re-run vault-save.sh with the updated source path. It will create a new version snapshot and update CURRENT.md and CHANGELOG.md automatically.

## Versioning

Skills use simple versioning: v1, v2, v3, etc. Each meaningful update creates a new snapshot in `versions/`. Prior versions are never deleted.

## Commit conventions

```
add: skill-name v1
update: skill-name v2
import: skill-name baseline
optimize: skill-name v3
archive: skill-name
supersede: old-skill -> new-skill
move: skill-name to new-category
```

## Categories

| Category | Purpose |
|---|---|
| app-usage | Claude Code meta-skills and workflow management |
| automation | CI/CD, linting, testing automation |
| data-processing | APIs, validation, data contracts |
| integrations | Third-party service integrations |
| misc | Skills that don't fit other categories |
| optimization | Performance and cost optimization |
| orchestration | Agent coordination and workflow execution |
| research | Debugging, analysis, investigation |
| review | Code review skills |
| security | Security hardening and access control |
| ui-ux | Frontend, design, and UI component skills |

## Safety

All content must comply with `docs/public-safety-policy.md` before being committed. Run `scripts/vault-check.sh <skill-folder>` to check a skill folder before committing.
