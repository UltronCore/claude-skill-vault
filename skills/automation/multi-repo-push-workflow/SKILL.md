---
name: multi-repo-push-workflow
description: Manage git push discipline across multiple repos (client site, skill vault, template repo). Defines where each type of work belongs, when to push, QA gates, and quick backup aliases. Configure your repo map once and use everywhere.
type: tool-routing
---

# Multi-Repo Push Workflow

Keeps multiple related repos in sync — client work, skill vault, and shared templates each pushed to the right place every time.

## Configuration (set once per project set)

Define your repo map in your project's CLAUDE.md:

```
REPOS:
  client_site:
    local: ~/Desktop/[CLIENT_SLUG]/
    remote: [USERNAME]/[CLIENT_REPO]          # private
    branch: main
    qa_cmd: node automation/run-all-checks.js  # optional

  skill_vault:
    local: ~/claude-skill-vault/
    remote: [USERNAME]/claude-skill-vault      # public
    branch: main

  template:
    local: ~/Desktop/[TEMPLATE_SLUG]/
    remote: [USERNAME]/[TEMPLATE_REPO]         # public
    branch: main
```

---

## Push Decision Tree

```
Did you edit client-facing files (HTML, assets, content, business data)?
  → Push to: client_site (run QA gate first if configured)

Did you write a new skill or update an existing one?
  → Push to: skill_vault

Did you write a reusable pattern that isn't client-specific?
  → Push to BOTH skill_vault AND template

Did you improve something in the template itself?
  → Push to template only (never push client-specific changes there)
```

---

## Standard Push Workflows

### Client site changes
```bash
cd CLIENT_LOCAL_PATH

# Run QA gate first (if configured) — must pass before push
QA_CMD

# Stage, commit, push
git add -A
git commit -m "feat|fix|chore: description of changes"
git push origin main
```

### New/updated skill
```bash
cd SKILL_VAULT_PATH

bash scripts/vault-save.sh SLUG ~/.claude/skills/SLUG.md CATEGORY
git commit -m "update: SLUG vN"
git push origin main
```

### Reusable template improvement
```bash
cd TEMPLATE_PATH

git add -A
git commit -m "feat|fix: description of template improvement"
git push origin BRANCH
```

---

## Quick Backup Aliases

Add these to your shell profile, substituting your actual paths:

```bash
# Backup client site (with QA)
alias push-client='cd CLIENT_LOCAL_PATH && QA_CMD && git add -A && git commit -m "chore: backup $(date +%Y-%m-%d)" && git push origin main'

# Backup skills
alias push-skills='cd SKILL_VAULT_PATH && git add -A && git commit -m "skill: backup $(date +%Y-%m-%d)" && git push origin main'
```

---

## Repo Health Check

```bash
# Quick status across all repos
for REPO in CLIENT_LOCAL_PATH SKILL_VAULT_PATH TEMPLATE_PATH; do
  echo "=== $REPO ==="
  cd "$REPO" && git status --short && git log --oneline -2
done
```

---

## Auto-Push Triggers

Push automatically (without being asked) after:
- ✅ QA passes at 100% after a significant feature
- ✅ New skill written and tested
- ✅ Reusable pattern documented
- ✅ Session ending with meaningful uncommitted work
- ✅ Before switching to a different project

---

## Rules

- Never force-push to shared/deploy branches
- Never push client-specific changes to a shared template repo
- Always run QA gate (if configured) before pushing client sites
- Include `Co-Authored-By` trailer in all AI-assisted commits

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/automation/multi-repo-push-workflow/.gitnexus
Last indexed: 2026-05-23
