---
name: new-website-repo
version: 1.0.0
description: >
  Complete workflow for spinning up a new client website from the
  local-service-site-template. Creates a private GitHub repo, copies the
  template, customises for the client, ensures the "Example User" footer credit is
  present, runs QA to 100%, and pushes — then updates the auto-push skill table
  and creates a project memory file.
tags: [workflow, git, new-site, setup, automation]
category: workflow
---

# New Website Repo Skill

Run this skill at the very start of every new client website engagement.
Never work directly in `local-service-site-template` for a client project.

---

## Quick Reference

```
Template source:  ~/Desktop/private-site-template/  (branch: alex-hair-design-site)
GitHub org:       UltronCore
Memory path:      ~/.claude/memory/project_<slug>.md
Skill table:      ~/claude-skill-vault/skills/workflow/auto-push/skill.md
```

---

## Step-by-Step Checklist

### 1. Choose a slug and target path

```
slug:        <client-name-kebab-case>           e.g. "tony-barber-shop"
local path:  ~/Desktop/<slug>/
github repo: UltronCore/<slug> (private)
```

### 2. Create the private GitHub repo

```bash
gh repo create UltronCore/<slug> --private --description "<Client Name> website"
```

Do **not** initialise with a README (we push our own content).

### 3. Copy the template

```bash
rsync -av --exclude='.git' \
  ~/Desktop/private-site-template/ \
  ~/Desktop/<slug>/
```

### 4. Initialise git and link to GitHub

```bash
cd ~/Desktop/<slug>
git init
git remote add origin https://github.com/UltronCore/<slug>.git
git add -A
git commit -m "chore: init from local-service-site-template

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push -u origin main
```

### 5. Customise for the client

Replace all placeholder content in `index.html` (and any other HTML files):

| Token | Replace with |
|-------|-------------|
| Business name | Client's real business name |
| Address / phone / hours | Client's real info |
| Color palette | Client's brand colors |
| Hero images | Client's actual photos |
| Services list | Client's real services |
| Social links | Client's real social URLs |
| `<title>` / meta description | SEO-ready client copy |

Also update:
- `business-profile.json` — all business fields
- `sitemap.xml` — correct domain
- `robots.txt` — correct domain
- `llms.txt` — correct business summary
- `assets/images/` — swap placeholder images for client images

### 6. Add the "Example User" footer credit

Every new site **must** include this before the first content push:

```html
<p class="text-center text-xs mt-3" style="color: rgba(248,244,237,0.18); letter-spacing: 0.08em;">
  Site designed &amp; built by <span style="color: rgba(248,244,237,0.32); font-weight: 500;">Example User</span>
</p>
```

Place it inside the `<footer>` block, after all other footer content.
Do **not** push without this present.

### 7. Run QA — must be 100%

```bash
cd ~/Desktop/<slug>
node automation/run-all-checks.js
```

Fix every failure before proceeding. Do not push with a non-100% score.

### 8. Commit and push the customised site

```bash
git add -A
git commit -m "feat: initial client build for <Client Name>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push origin main
```

### 9. Update the auto-push skill table

Add a row to the **Known Repos** table in
`~/claude-skill-vault/skills/workflow/auto-push/skill.md`:

```markdown
| <Client Name> | `~/Desktop/<slug>/` | `UltronCore/<slug>` (🔒 private) | `main` | ✅ Yes |
```

### 10. Create a project memory file

Create `~/.claude/memory/project_<slug>.md` with at minimum:

```markdown
# <Client Name> — Project Memory

## Repo & Location
- **Private GitHub:** https://github.com/UltronCore/<slug> (PRIVATE)
- **Local path:** `~/Desktop/<slug>/` ← work here exclusively

## Stack
- Plain HTML + Tailwind CDN + Alpine.js 3.14.1 (no build step)
- Local server: `python3 -m http.server 4173 --bind 127.0.0.1`

## Business Info
- **Name:** <Client Name>
- **Address:** <Address>
- **Phone:** <Phone>
- **Hours:** <Hours>

## Current State (<date>)
- QA: **X/X checks** (100%)

## Color Palette
- (fill in)

## Git Workflow
cd ~/Desktop/<slug>
node automation/run-all-checks.js   # must be 100%
git add <files>
git commit -m "feat|fix|chore: description"
git push origin main
```

Also add a line to `~/.claude/memory/MEMORY.md`:

```markdown
- [<Client Name>](./project_<slug>.md) — PRIVATE client site, at ~/Desktop/<slug> and https://github.com/UltronCore/<slug> (private)
```

### 11. Push skill vault updates

```bash
cd ~/claude-skill-vault
git add -A
git commit -m "skill(workflow): add <slug> to auto-push repo table

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git pull --rebase origin main && git push origin main
```

---

## Known Template Source

The base template lives at:

```
Local:  ~/Desktop/private-site-template/
Branch: alex-hair-design-site
GitHub: UltronCore/private-site-template (reference only — never push client work here)
```

Pull the latest template before starting a new project if it has been updated:

```bash
cd ~/Desktop/private-site-template
git pull origin alex-hair-design-site
```

---

## Checklist Summary

- [ ] Slug and path chosen
- [ ] Private GitHub repo created (`gh repo create ... --private`)
- [ ] Template copied with `rsync --exclude='.git'`
- [ ] Git init + remote + first commit pushed
- [ ] All placeholder content replaced (HTML, JSON, XML, txt)
- [ ] Client images in `assets/images/`
- [ ] "Example User" footer credit present
- [ ] QA passing at 100% (`node automation/run-all-checks.js`)
- [ ] Customised site committed and pushed
- [ ] `auto-push` skill table row added
- [ ] Project memory file created
- [ ] `MEMORY.md` index updated
- [ ] Skill vault committed and pushed

---

*Last updated: 2026-05-08*
