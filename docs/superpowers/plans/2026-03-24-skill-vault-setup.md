# Skill Vault — Initial Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a GitHub-backed Skill Vault that imports all 40+ existing skills, versions them, organizes them by category, and auto-saves future skill work.

**Architecture:** Local repo at ~/claude-skill-vault with category folders, per-skill docs, a central registry, and lightweight automation scripts. Skills imported as v1 baseline snapshots. Git-committed locally first; pushed after GitHub auth.

**Tech Stack:** bash, python3, git, gh CLI

---

### Task 1: Create full directory structure
- [ ] Create all category folders and scaffold files
- [ ] Create _registry, _archive, _obsolete, _templates, state, docs, scripts
- [ ] Commit: `init: vault directory structure`

### Task 2: Import local skills (parallel)
- [ ] Read each SKILL.md, sanitize, categorize
- [ ] Create per-skill folder with SKILL.md, README.md, CURRENT.md, metadata.json, CHANGELOG.md, skill-memory.md, versions/v1/
- [ ] Commit: `import: local skills baseline`

### Task 3: Import official skills (parallel)
- [ ] Same as Task 2 for official/superpowers skills
- [ ] Commit: `import: official skills baseline`

### Task 4: Build registry, lineage, indexes
- [ ] Populate registry.json, categories.json, lineage.json, featured.json
- [ ] Generate category INDEX.md files
- [ ] Commit: `feat: registry and category indexes`

### Task 5: Create automation scripts
- [ ] vault-save.sh — saves a new skill version
- [ ] vault-import.sh — imports a skill from install path
- [ ] vault-check.sh — runs safety check on a skill folder
- [ ] Commit: `feat: automation scripts`

### Task 6: Create docs and README
- [ ] Top-level README.md
- [ ] docs/public-safety-policy.md
- [ ] docs/repository-guidelines.md
- [ ] docs/lineage-overview.md
- [ ] docs/optimization-policy.md
- [ ] Commit: `docs: vault documentation`

### Task 7: GitHub — create repo and push
- [ ] gh auth login (user action)
- [ ] gh repo create claude-skill-vault --public
- [ ] git remote add origin, push
