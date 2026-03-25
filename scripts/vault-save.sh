#!/usr/bin/env bash
# vault-save.sh — Save or update a skill in the vault
# Usage: scripts/vault-save.sh <slug> <source-skill-md-path> <category>
#
# Creates or updates a skill folder, snapshots the current version,
# and stages changes for commit.

set -euo pipefail

SLUG="${1:-}"
SOURCE="${2:-}"
CATEGORY="${3:-}"

if [[ -z "$SLUG" || -z "$SOURCE" || -z "$CATEGORY" ]]; then
  echo "Usage: vault-save.sh <slug> <source-skill-md-path> <category>"
  exit 1
fi

VAULT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$VAULT_ROOT/skills/$CATEGORY/$SLUG"
TODAY=$(date +%Y-%m-%d)

# Determine next version
if [[ -d "$SKILL_DIR/versions" ]]; then
  LAST_V=$(ls "$SKILL_DIR/versions/" 2>/dev/null | grep '^v[0-9]' | sort -V | tail -1 | tr -d 'v')
  NEXT_V="v$((LAST_V + 1))"
else
  NEXT_V="v1"
fi

# Create directories
mkdir -p "$SKILL_DIR/versions/$NEXT_V"

# Copy SKILL.md
cp "$SOURCE" "$SKILL_DIR/SKILL.md"
cp "$SOURCE" "$SKILL_DIR/versions/$NEXT_V/SKILL.md"

# Update CURRENT.md
cat > "$SKILL_DIR/CURRENT.md" <<EOF
**Skill:** $SLUG
**Version:** $NEXT_V
**Status:** active
**Category:** $CATEGORY
**Last updated:** $TODAY
**Source:** created-in-vault
EOF

# Append CHANGELOG if exists, else create
if [[ -f "$SKILL_DIR/CHANGELOG.md" ]]; then
  echo "- $NEXT_V ($TODAY): updated" >> "$SKILL_DIR/CHANGELOG.md"
else
  cat > "$SKILL_DIR/CHANGELOG.md" <<EOF
## Changelog
- $NEXT_V ($TODAY): initial save
EOF
fi

# Create metadata if missing
if [[ ! -f "$SKILL_DIR/metadata.json" ]]; then
  cat > "$SKILL_DIR/metadata.json" <<EOF
{
  "name": "$SLUG",
  "slug": "$SLUG",
  "version": "$NEXT_V",
  "status": "active",
  "created": "$TODAY",
  "updated": "$TODAY",
  "source": "created-in-vault",
  "category": "$CATEGORY",
  "tags": [],
  "public_safe": true,
  "replaced_by": null,
  "derived_from": null,
  "related_skills": [],
  "featured": false
}
EOF
else
  # Update version and updated fields in metadata.json
  python3 -c "
import json, sys
with open('$SKILL_DIR/metadata.json') as f:
    d = json.load(f)
d['version'] = '$NEXT_V'
d['updated'] = '$TODAY'
with open('$SKILL_DIR/metadata.json', 'w') as f:
    json.dump(d, f, indent=2)
print('metadata updated')
"
fi

# Create README if missing
if [[ ! -f "$SKILL_DIR/README.md" ]]; then
  cat > "$SKILL_DIR/README.md" <<EOF
# $SLUG

**Category:** $CATEGORY
**Status:** active
**Version:** $NEXT_V

## What it does
TODO: add description

## When to use
- TODO

## What it produces
TODO

## Related skills
None identified
EOF
fi

# Create skill-memory if missing
if [[ ! -f "$SKILL_DIR/skill-memory.md" ]]; then
  cat > "$SKILL_DIR/skill-memory.md" <<EOF
# Skill Memory: $SLUG

## Purpose
TODO: add operational summary

## Category notes
Belongs in $CATEGORY.

## Relationships
None identified.

## Maintenance notes
None.
EOF
fi

# Run safety check
"$VAULT_ROOT/scripts/vault-check.sh" "$SKILL_DIR" || {
  echo "WARNING: Safety check flagged issues in $SKILL_DIR — review before committing"
}

# Stage for commit
cd "$VAULT_ROOT"
git add "skills/$CATEGORY/$SLUG/"

echo "Saved: $SLUG $NEXT_V -> skills/$CATEGORY/$SLUG/"
echo "Commit with: git commit -m 'update: $SLUG $NEXT_V'"
