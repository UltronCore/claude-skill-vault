# cloudflare-pages-autopush

**Category:** automation | **Status:** active | **Version:** v1

## What it does
Auto-commits and pushes any Cloudflare Pages project to GitHub — both on explicit request and proactively at session end whenever project files were touched. Generates descriptive commit messages and confirms the Cloudflare deployment will follow.

## When to use
- Any project hosted on Cloudflare Pages
- Sessions where you want zero uncommitted work left behind
- Teams or solo devs who want consistent git hygiene without thinking about it

## What it produces
- A staged, committed, and pushed git state
- A descriptive commit message summarizing actual changes
- Confirmation of push with Cloudflare deploy ETA

## Setup
Configure PROJECT_PATH, REMOTE_REPO, and BRANCH once at the top of your CLAUDE.md for the project.

## Related skills
- auto-push — general-purpose push for any project
- multi-repo-push-workflow — managing push across multiple repos
