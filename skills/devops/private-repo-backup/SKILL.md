---
name: private-repo-backup
version: 1.0.0
description: >
  Auto-backup skill for the Example Client Site private production repo
  and the Claude Skill Vault. Defines where all client work, new skills,
  and reusable templates must be committed and pushed.
tags: [workflow, git, backup, alex-hair, private-repo]
category: workflow
---

# Private Repo Backup — Example Client Site

## Repository Map

| Repo | GitHub | Local Path | Visibility | Branch |
|------|--------|-----------|------------|--------|
| **Example Client Site** (client site) | `UltronCore/private-client-site` | `~/Desktop/private-client-site/` | **Private** | `main` |
| **Claude Skill Vault** (reusable skills) | `UltronCore/claude-skill-vault` | `~/claude-skill-vault/` | Public | `main` |
| Local Service Site Template (upstream template) | `UltronCore/private-site-template` | `~/Desktop/private-site-template/` | Public | `alex-hair-design-site` |

> **Rule:** All day-to-day client work happens in `private-client-site`. The template repo is upstream reference only — do NOT push client-specific changes there.

---

## When to Push — Decision Tree

```
Did you edit index.html, assets/, accessibility.html, llms.txt, robots.txt,
business-profile.json, or any client-facing file?
  → Push to: private-client-site (main)

Did you write a new skill or update an existing skill in claude-skill-vault?
  → Push to: claude-skill-vault (main)

Did you write a reusable pattern or template that isn't client-specific?
  → Push to BOTH repos (skill vault + template as reference)

Did you add/change anything in local-service-site-template?
  → Only push there if it's a template-level improvement, not Alex-specific
```

---

## Standard Commit Workflow

### Client site changes (private-client-site)
```bash
cd ~/Desktop/private-client-site

# Run QA first — must pass 100%
node automation/run-all-checks.js

# Stage and commit
git add <files>
git commit -m "feat|fix|chore: short description"

# Push to private repo
git push origin main
```

### New skill created (claude-skill-vault)
```bash
cd ~/claude-skill-vault

# After writing the skill file
git add skills/<category>/<skill-name>/skill.md
git commit -m "skill(category): add <skill-name>"
git push origin main
```

---

## Quick Backup Commands

```bash
# Backup all client site changes
alias push-alex='cd ~/Desktop/private-client-site && node automation/run-all-checks.js && git add -A && git commit -m "chore: auto-backup $(date +%Y-%m-%d)" && git push origin main'

# Backup new/updated skills
alias push-skills='cd ~/claude-skill-vault && git add -A && git commit -m "skill: auto-backup $(date +%Y-%m-%d)" && git push origin main'
```

---

## What Lives in Each Repo

### `private-client-site` (private — all client work goes here)
```
index.html              ← production site
assets/                 ← images, JS, CSS
accessibility.html      ← WCAG statement
llms.txt                ← AI guidance
robots.txt              ← crawl rules
business-profile.json   ← structured business data
sitemap.xml / .html     ← sitemaps
automation/             ← QA suite (run before every push)
docs/                   ← project docs, CRM notes, photo review
feature-packs/          ← optional feature modules
skills/                 ← site-scoped skills (local to project)
claude-project/         ← Claude context bundles for handoff
```

### `claude-skill-vault` (public — reusable across all projects)
```
skills/ui-ux/ada-wcag-compliance/   ← WCAG 2.2 AA skill
skills/workflow/private-repo-backup/ ← THIS skill
skills/<category>/<name>/skill.md   ← all other skills
```

---

## Auto-Backup Triggers

Automatically push after completing any of these:
- ✅ QA passes at 100% after a significant feature
- ✅ New skill file written and tested
- ✅ New reusable HTML/CSS pattern documented
- ✅ Session ending with meaningful uncommitted work
- ✅ Before switching to a different project

---

## Repo Health Checks

```bash
# Verify private repo is up to date
cd ~/Desktop/private-client-site && git status && git log --oneline -3

# Verify skill vault is up to date
cd ~/claude-skill-vault && git status && git log --oneline -3

# Quick QA on client site
cd ~/Desktop/private-client-site && node automation/run-all-checks.js 2>&1 | tail -5
```

---

## Handoff Context

- **Business:** Example Client Site
- **Address:** 6039 Chippewa St, St. Louis, MO 63109
- **Phone:** (314) 475-4365
- **Stack:** Plain HTML + Tailwind CDN + Alpine.js 3.14.1 (no build step)
- **Local server:** `python3 -m http.server 4173 --bind 127.0.0.1`
- **ngrok tunnel:** run `ngrok http 4173` (URL rotates unless paid plan)
- **Private repo:** https://github.com/UltronCore/private-client-site
- **QA suite:** `node automation/run-all-checks.js` — must hit 100% before push
- **Current check count:** 466 checks across 7 suites

---

*Last updated: 2026-05-08*

## Related Skills
- `vault-auto-sync` — vault backup
- `git-guardrails-claude-code` — git safety
- `multi-repo-push-workflow` — multi-repo management

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/private-repo-backup/.gitnexus
Last indexed: 2026-05-23
