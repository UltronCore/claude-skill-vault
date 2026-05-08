# private-cleaners-project-autopush

Auto-commit and push the Example Cleaners Site site to GitHub — both on demand and proactively.

## When to Use

**Explicit triggers** (user says any of these):
- "push to github", "push it", "push changes", "update github", "commit and push"
- "save it", "deploy it", "ship it", "push this"
- Any phrase ending in "...to github" or "...to git"

**Proactive triggers** (run WITHOUT being asked) after any session where you:
- Edited `index.html`, `ops/index.html`, `assets/*.js`, `assets/*.css`, or `content/site.json`
- Added or deleted files in the project
- Made UI, CRM, or content changes

The rule: **if you touched the project, push it before the session ends.**

## Project Context

- **Path**: `/Users/localuser/Desktop/private-cleaners-project/`
- **Remote**: `https://github.com/UltronCore/private-cleaners-site`
- **Branch**: `main`
- **Hosting**: Cloudflare Pages (auto-deploys on push to main)

## Execution Steps

### Step 1 — Check status
```bash
cd /Users/localuser/Desktop/private-cleaners-project
git status --short
git log --oneline -3
```

### Step 2 — Stage all changes
```bash
cd /Users/localuser/Desktop/private-cleaners-project
git add -A
```

### Step 3 — Commit with a descriptive message
Generate a commit message that describes WHAT changed (not just "update files").
Format: `<type>: <summary of actual changes>`

Examples:
- `feat: hero headline upgrade, Our Story section, 6-card services grid`
- `fix: WCAG focus ring contrast, float CTA restore, 404 page`
- `chore: cleanup temp files, stage Codex changes`

```bash
git commit -m "<generated message>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

If nothing to commit, skip to Step 4.

### Step 4 — Push
```bash
git push origin main 2>&1
```

### Step 5 — Confirm
Report the commit hash and confirm push succeeded. Example:
> ✅ Pushed `abc1234` to `UltronCore/private-cleaners-site` — Cloudflare Pages will deploy in ~60 seconds.

## Proactive Auto-Push (End of Session)

At the end of any session where project files were modified:
1. Run `git status --short` to check for unstaged changes
2. If any exist — run the full Steps 1–5 above WITHOUT asking
3. If already clean — confirm: "Repo is clean, nothing to push."

## Error Handling

| Error | Fix |
|-------|-----|
| `nothing to commit` | Skip commit, still try push in case local branch is ahead |
| `rejected (non-fast-forward)` | Run `git pull --rebase origin main` then retry push |
| `remote: Permission denied` | Check git credentials — user needs to re-auth |
| Merge conflict | Stage safe files, flag conflict files to user |

## Notes

- Never force-push (`--force`) to main
- Never skip the pre-commit hooks (`--no-verify`)
- Always include `Co-Authored-By` trailer in commit message
- Cloudflare Pages deploys automatically within ~60s of a push
