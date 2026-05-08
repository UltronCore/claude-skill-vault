# multi-repo-push-workflow

**Category:** automation | **Status:** active | **Version:** v1

## What it does
Defines git push discipline across multiple related repos: client site, skill vault, and upstream template. Answers "which repo does this change belong in?" and "did I push everything before ending this session?"

## When to use
- Working across 2-3 related repos simultaneously
- Client site work alongside skill vault updates
- Any project with a shared template upstream

## What it produces
- Clear push decision tree for every type of change
- Quick bash aliases for fast backups
- Health-check commands for all repos at once

## Setup
Define your REPOS map once in your project's CLAUDE.md — paths, remotes, branches, optional QA commands.

## Related skills
- cloudflare-pages-autopush — specialized for Cloudflare Pages projects
- auto-push — simple single-repo auto-push
