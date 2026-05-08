---
name: cloudflare-pages-autopush
description: Auto-commit and push any Cloudflare Pages project to GitHub — both on-demand and proactively at session end. Set PROJECT_PATH and REMOTE_REPO once and never think about it again.
type: tool-routing
---

# Cloudflare Pages Auto-Push

Auto-commit and push your Cloudflare Pages project to GitHub on demand and proactively.

## Configuration (set once per project)

| Variable | Value |
|----------|-------|
| `PROJECT_PATH` | Local path to the project root (e.g. `~/Desktop/my-project/`) |
| `REMOTE_REPO` | GitHub remote (e.g. `username/repo-name`) |
| `BRANCH` | Deploy branch (usually `main`) |

Cloudflare Pages auto-deploys within ~60s of a push to the deploy branch.

---

## When to Use

**On-demand** — user says any of:
- "push to github", "push it", "push changes", "update github", "commit and push"
- "save it", "deploy it", "ship it", "push this"
- Any phrase ending in "...to github" or "...to git"

**Proactive** — run WITHOUT being asked after any session where you:
- Edited HTML, JS, CSS, or content files in the project
- Added or deleted files
- Made any UI or content changes

**The rule: if you touched the project, push it before the session ends.**

---

## Execution Steps

### Step 1 — Check status
```bash
cd PROJECT_PATH
git status --short
git log --oneline -3
```

### Step 2 — Stage all changes
```bash
cd PROJECT_PATH
git add -A
```

### Step 3 — Commit with a descriptive message
Generate a message describing WHAT changed — not just "update files".

Format: `<type>: <summary of actual changes>`

Examples:
- `feat: hero section redesign, added testimonials grid`
- `fix: mobile nav overflow, contrast ratio on CTA button`
- `chore: cleanup temp files, update content`

```bash
git commit -m "<generated message>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

If nothing to commit, skip to Step 4.

### Step 4 — Push
```bash
cd PROJECT_PATH
git push origin BRANCH 2>&1
```

### Step 5 — Confirm
Report the commit hash and confirm push succeeded:
> ✅ Pushed `abc1234` to `REMOTE_REPO` — Cloudflare Pages will deploy in ~60 seconds.

---

## Proactive Auto-Push (End of Session)

At the end of any session where project files were modified:
1. `git status --short` — check for unstaged changes
2. If any exist — run Steps 1–5 above WITHOUT asking
3. If clean — confirm: "Repo is clean, nothing to push."

---

## Error Handling

| Error | Fix |
|-------|-----|
| `nothing to commit` | Skip commit, still try push in case local branch is ahead |
| `rejected (non-fast-forward)` | `git pull --rebase origin BRANCH` then retry push |
| `remote: Permission denied` | Check git credentials — re-auth needed |
| Merge conflict | Stage safe files, flag conflicted files to user |

---

## Rules

- Never force-push (`--force`) to the deploy branch
- Never skip pre-commit hooks (`--no-verify`)
- Always include `Co-Authored-By` trailer in commit message
