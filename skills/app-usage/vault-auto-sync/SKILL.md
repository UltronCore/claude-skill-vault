---
name: vault-auto-sync
description: >
  Syncs the claude-skill-vault GitHub repo to both ~/.claude/skills (Claude Code CLI) and the Claude desktop app personal skills directory. Run after any push to the skill vault, or invoke manually to pull latest skills from GitHub and install them everywhere. Detects new skills, installs missing ones, and reports what changed.
---

# Vault Auto-Sync

Pulls the latest skill vault from GitHub and installs any new or updated skills into all active locations:
- `~/.claude/skills/` — Claude Code CLI runtime
- `~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/*/skills/` — Claude desktop app personal skills

## When to use
- After pushing new skills to `UltronCore/claude-skill-vault`
- When you notice a skill is in the vault but not showing up in Claude Code or the Claude app
- Periodic check to ensure all three layers stay in sync

## What it does

```bash
#!/bin/bash
# vault-sync.sh — run this directly or via the post-merge hook

VAULT="$HOME/claude-skill-vault"
CC_SKILLS="$HOME/.claude/skills"
CLAUDE_APP_SKILLS=$(find "$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin" -maxdepth 3 -type d -name "skills" 2>/dev/null | head -1)

# 1. Pull latest vault from GitHub
cd "$VAULT" && git pull --rebase origin main

# 2. Find all top-level skill slugs in vault
installed_cc=0; installed_app=0

find "$VAULT/skills" -maxdepth 3 -name "SKILL.md" | grep -v '/versions/' | while read -r skill_md; do
  slug=$(echo "$skill_md" | sed 's|.*/skills/[^/]*/||;s|/SKILL.md||')
  
  # Install to Claude Code CLI
  if [ ! -f "$CC_SKILLS/$slug/SKILL.md" ]; then
    mkdir -p "$CC_SKILLS/$slug"
    cp "$skill_md" "$CC_SKILLS/$slug/SKILL.md"
    echo "CC: installed $slug"
    ((installed_cc++))
  fi
  
  # Install to Claude app
  if [ -n "$CLAUDE_APP_SKILLS" ] && [ ! -f "$CLAUDE_APP_SKILLS/$slug/SKILL.md" ]; then
    mkdir -p "$CLAUDE_APP_SKILLS/$slug"
    cp "$skill_md" "$CLAUDE_APP_SKILLS/$slug/SKILL.md"
    echo "APP: installed $slug"
    ((installed_app++))
  fi
done

echo "Sync complete — CC: $installed_cc new | App: $installed_app new"
```

## Usage

### Manual run
```bash
bash ~/claude-skill-vault/scripts/vault-sync.sh
```

### Automatic (git hook — fires on every `git pull` / `git merge`)
The hook is installed at `~/claude-skill-vault/.git/hooks/post-merge`.

### Automatic (launchd — runs every 30 min, polls GitHub)
The plist is installed at `~/Library/LaunchAgents/com.localuser.vault-auto-sync.plist`.
Load with: `launchctl load ~/Library/LaunchAgents/com.localuser.vault-auto-sync.plist`

## Locations synced

| Target | Path |
|--------|------|
| Claude Code CLI | `~/.claude/skills/<slug>/SKILL.md` |
| Claude desktop app | `~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/<id>/skills/<slug>/SKILL.md` |
| Vault (source) | `~/claude-skill-vault/skills/<category>/<slug>/SKILL.md` |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/app-usage/vault-auto-sync/.gitnexus
Last indexed: 2026-05-23
