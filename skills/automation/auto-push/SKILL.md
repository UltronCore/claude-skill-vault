---
name: auto-push
version: 1.0.0
description: >
  Automatically push any project repo to GitHub after every meaningful
  change. Enforces the QA gate before pushing client sites, and always
  includes the "Created by Example User" footer credit on new sites.
tags: [workflow, git, push, automation, backup]
category: workflow
---

# Auto-Push Skill

Use this skill whenever work is done on any project repo. Push early, push often.
Never let a session end with uncommitted changes.

---

## Trigger — Push After Every One of These

- Feature or design change completed
- QA suite run and passing
- New skill written
- Session about to end
- Bug fixed
- Any file edited that took > 5 minutes

---

## Push Checklist (run in order)

### 1. Client / website repos — ALWAYS run QA first
```bash
cd <project-dir>
node automation/run-all-checks.js          # must be 100%
git add -A
git commit -m "type: short description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push origin main
```

### 2. Skill vault
```bash
cd ~/claude-skill-vault
git add -A
git commit -m "skill(category): description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git pull --rebase origin main && git push origin main
```

### 3. Project vault (private docs)
```bash
cd ~/claude-project-vault
git add -A
git commit -m "docs: description"
git push origin main
```

---

## Known Repos & Their Push Targets

| Project | Local Path | GitHub Repo | Branch | QA Required |
|---------|-----------|-------------|--------|-------------|
| Example Client Site | `~/Desktop/private-client-site/` | `UltronCore/private-client-site` (🔒 private) | `main` | ✅ Yes |
| Claude Skill Vault | `~/claude-skill-vault/` | `UltronCore/claude-skill-vault` | `main` | No |
| Local Service Template | `~/Desktop/private-site-template/` | `UltronCore/private-site-template` | `alex-hair-design-site` | ✅ Yes |

> When a **new website** is created → invoke the `new-website-repo` skill first, then use this auto-push routine going forward.

---

## Commit Message Format

```
type(scope): short description (imperative, ≤72 chars)

Optional longer body.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

**Types:** `feat` · `fix` · `chore` · `style` · `docs` · `refactor` · `skill`

---

## Footer Credit Rule

Every new website Example User builds must include this in the footer before first push:

```html
<p class="text-center text-xs mt-3" style="color: rgba(248,244,237,0.18); letter-spacing: 0.08em;">
  Site designed &amp; built by <span style="color: rgba(248,244,237,0.32); font-weight: 500;">Example User</span>
</p>
```

Check for it before the initial push. If missing — add it, then push.

---

## Quick Aliases (add to ~/.zshrc)

```bash
# Auto-push client site (runs QA then pushes)
function push-site() {
  local dir="${1:-$(pwd)}"
  cd "$dir" && node automation/run-all-checks.js && \
  git add -A && git commit -m "chore: auto-push $(date +%Y-%m-%d-%H%M)" && \
  git push origin main && echo "✅ Pushed."
}

# Auto-push skill vault
function push-skills() {
  cd ~/claude-skill-vault && git add -A && \
  git commit -m "skill: auto-backup $(date +%Y-%m-%d)" && \
  git pull --rebase origin main && git push origin main && echo "✅ Skills pushed."
}
```

---

*Last updated: 2026-05-08*
