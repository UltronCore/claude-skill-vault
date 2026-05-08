# temporal-developer

**Source:** `temporalio/skill-temporal-developer` (official Temporal Technologies repo)
**Active install:** `~/.claude/skills/temporal-developer/`
**Vault entry purpose:** Provenance tracking and update management

---

## Provenance

| Field | Value |
|-------|-------|
| Origin org | `temporalio` (Temporal Technologies, Inc. — official) |
| Repo | https://github.com/temporalio/skill-temporal-developer |
| Version | 0.1.0 (Public Preview) |
| License | MIT |
| Install date | 2026-03-26 |
| Install method | Manual `git clone` to `~/.claude/skills/temporal-developer/` |
| Trust level | HIGH — pure markdown, no scripts, verified commits, official org |

## Content

The skill is 100% markdown. Structure:
- `SKILL.md` — core skill definition with trigger phrases and architecture overview
- `references/core/` — determinism, patterns, gotchas, versioning, troubleshooting, error-reference, AI patterns
- `references/python/` — Python SDK specific guidance (14 files)
- `references/typescript/` — TypeScript SDK specific guidance (11 files)
- `references/go/` — Go SDK specific guidance (11 files)

## Update Procedure

```bash
cd ~/.claude/skills/temporal-developer
git pull origin main
```

No post-pull steps required — content is read directly by Claude Code.

## Companion Repo

The official plugin marketplace wrapper is `temporalio/agent-skills`.
Plugin path (alternative install): `/plugin marketplace add temporalio/agent-skills`
This install uses manual clone to maintain explicit version control.
