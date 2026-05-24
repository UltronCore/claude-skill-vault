---
name: gitnexus-obsidian-github
description: Unified workflow linking GitHub repos, GitNexus knowledge graphs, and Obsidian vault notes for seamless project intelligence
---

# GitNexus + Obsidian + GitHub — Unified Integration Skill

## Overview

This skill connects three systems into one unified project intelligence layer:
- **GitHub** — source of truth for code and history
- **GitNexus** — knowledge graph for code intelligence (dependencies, clusters, call chains)
- **Obsidian** — personal knowledge base for project notes, decisions, and docs

## The Hub

- Obsidian hub note: `~/obsidian-vault/GitNexus-Hub.md`
- Project notes: `~/obsidian-vault/Projects/<ProjectName>.md`
- GitNexus global config: `~/.gitnexus/global-config.json`
- Skills index: `~/.claude/gitnexus-skills-index.json`

## When Opening a New Project in Claude Code

1. GitNexus MCP auto-activates (configured in `.claude/settings.json`)
2. Run `gitnexus analyze .` if index is stale (>1 week old)
3. Check Obsidian for the project note: `~/obsidian-vault/Projects/<name>.md`
4. Surface relevant notes using GitNexus graph traversal

## Refresh Workflow (run after major changes)

```bash
# Refresh GitNexus index
gitnexus analyze .
gitnexus analyze --skills .

# Then update Obsidian note's last_synced date manually or via MCP
```

## Creating a New Project Hub Note in Obsidian

Use this template when adding a new project:

```markdown
---
tags: [project, gitnexus, github]
github: UltronCore/<repo>
gitnexus_index: <path>/.gitnexus
last_synced: YYYY-MM-DD
---

# Project Name

## Overview
- GitHub: [link]
- Local path: <path>
- Stack: <stack>

## Knowledge Graph
`gitnexus analyze "<path>"`

## Notes
```

## GitHub → GitNexus → Obsidian Flow

```
GitHub push
    ↓
gitnexus analyze . (refresh graph)
    ↓
Query graph for changes: gitnexus explore . "what changed"
    ↓
Update Obsidian project note with key findings
    ↓
Commit Obsidian vault (if it's a git repo)
```

## Obsidian → GitNexus → GitHub Flow

```
Open Obsidian project note
    ↓
Read GitNexus index path from frontmatter
    ↓
gitnexus explore "<path>" "<concept from note>"
    ↓
Navigate to relevant GitHub files/PRs
    ↓
Make changes with full context
```

## Key Commands

| Action | Command |
|--------|---------|
| Refresh project graph | `gitnexus analyze "<project-path>"` |
| Explore concept in graph | `gitnexus explore "<path>" "<concept>"` |
| Refresh skills graph | `gitnexus analyze --skills ~/.claude/skills/` |
| Open GitNexus MCP | Automatic via .claude/settings.json |
| Refresh all projects | See hub note refresh script |

## Related Skills
- `gitnexus-guide` — full GitNexus usage guide
- `gitnexus-exploring` — deep graph exploration
- `gitnexus-pr-review` — PR review powered by GitNexus
- `obsidian-automation` — Obsidian MCP automation
- `github-actions-advanced` — GitHub CI/CD
- `auto-push` — auto-push workflow

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/gitnexus-obsidian-github/.gitnexus
Last indexed: 2026-05-23
