#!/bin/bash
# vault-sync.sh
# Syncs claude-skill-vault → ~/.claude/skills AND Claude desktop app personal skills
# Safe to run repeatedly; only installs missing skills (does not overwrite existing)
#
# Usage:
#   bash ~/claude-skill-vault/scripts/vault-sync.sh          # manual run
#   bash ~/claude-skill-vault/scripts/vault-sync.sh --pull   # pull from GitHub first

set -euo pipefail

VAULT="$HOME/claude-skill-vault"
CC_SKILLS="$HOME/.claude/skills"

# Find Claude app personal skills dir (stable across sessions — only one plugin session exists)
CLAUDE_APP_SKILLS=$(find "$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin" \
  -maxdepth 4 -type d -name "skills" 2>/dev/null | head -1)

# ── Pull from GitHub if requested ──────────────────────────────────────────────
if [[ "${1:-}" == "--pull" ]]; then
  echo "Pulling vault from GitHub..."
  cd "$VAULT" && git pull --rebase origin main
fi

# ── Sync loop ──────────────────────────────────────────────────────────────────
installed_cc=0
installed_app=0
updated_cc=0
updated_app=0

while IFS= read -r skill_md; do
  # Extract slug: strip vault prefix, category dir, and /SKILL.md
  rel="${skill_md#$VAULT/skills/}"
  slug="${rel#*/}"          # strip category/
  slug="${slug%/SKILL.md}"  # strip /SKILL.md

  # Skip version directories
  if [[ "$slug" == *"/versions/"* ]]; then
    continue
  fi

  # ── Claude Code CLI ──
  target_cc="$CC_SKILLS/$slug/SKILL.md"
  if [ ! -f "$target_cc" ]; then
    mkdir -p "$CC_SKILLS/$slug"
    cp "$skill_md" "$target_cc"
    echo "  [CC +new] $slug"
    ((installed_cc++)) || true
  fi

  # ── Claude desktop app ──
  if [ -n "$CLAUDE_APP_SKILLS" ]; then
    target_app="$CLAUDE_APP_SKILLS/$slug/SKILL.md"
    if [ ! -f "$target_app" ]; then
      mkdir -p "$CLAUDE_APP_SKILLS/$slug"
      cp "$skill_md" "$target_app"
      echo "  [APP +new] $slug"
      ((installed_app++)) || true
    fi
  fi

done < <(find "$VAULT/skills" -maxdepth 3 -name "SKILL.md" | grep -v '/versions/')

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          Vault Sync Complete              ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Claude Code CLI  : +${installed_cc} new skills"
echo "║  Claude App       : +${installed_app} new skills"
echo "║  CC total         : $(ls "$CC_SKILLS" | wc -l | tr -d ' ') skills active"
if [ -n "$CLAUDE_APP_SKILLS" ]; then
  echo "║  App total        : $(ls "$CLAUDE_APP_SKILLS" | wc -l | tr -d ' ') skills active"
fi
echo "╚══════════════════════════════════════════╝"
