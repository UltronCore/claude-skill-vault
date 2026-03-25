#!/usr/bin/env bash
# vault-import.sh — Import an existing skill as a baseline snapshot
# Usage: scripts/vault-import.sh <slug> <source-skill-md-path> <category>
#
# Imports a skill that already exists outside the vault.
# Creates all required files and marks it as imported-existing.

set -euo pipefail

SLUG="${1:-}"
SOURCE="${2:-}"
CATEGORY="${3:-}"

if [[ -z "$SLUG" || -z "$SOURCE" || -z "$CATEGORY" ]]; then
  echo "Usage: vault-import.sh <slug> <source-skill-md-path> <category>"
  exit 1
fi

VAULT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$VAULT_ROOT/skills/$CATEGORY/$SLUG"
TODAY=$(date +%Y-%m-%d)

if [[ -d "$SKILL_DIR" ]]; then
  echo "Skill already exists at $SKILL_DIR — use vault-save.sh to update"
  exit 1
fi

mkdir -p "$SKILL_DIR/versions/v1"

# Copy SKILL.md
cp "$SOURCE" "$SKILL_DIR/SKILL.md"
cp "$SOURCE" "$SKILL_DIR/versions/v1/SKILL.md"

cat > "$SKILL_DIR/CURRENT.md" <<EOF
**Skill:** $SLUG
**Version:** v1
**Status:** active
**Category:** $CATEGORY
**Last updated:** $TODAY
**Source:** imported-existing
EOF

cat > "$SKILL_DIR/CHANGELOG.md" <<EOF
## Changelog
- v1 ($TODAY): imported existing skill as baseline
EOF

cat > "$SKILL_DIR/metadata.json" <<EOF
{
  "name": "$SLUG",
  "slug": "$SLUG",
  "version": "v1",
  "status": "active",
  "created": "$TODAY",
  "updated": "$TODAY",
  "source": "imported-existing",
  "category": "$CATEGORY",
  "tags": [],
  "public_safe": true,
  "replaced_by": null,
  "derived_from": null,
  "related_skills": [],
  "featured": false
}
EOF

cat > "$SKILL_DIR/README.md" <<EOF
# $SLUG

**Category:** $CATEGORY
**Status:** active
**Version:** v1

## What it does
TODO: add description

## When to use
- TODO

## What it produces
TODO

## Related skills
None identified
EOF

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

# Run safety check
"$VAULT_ROOT/scripts/vault-check.sh" "$SKILL_DIR" || {
  echo "WARNING: Safety check flagged issues in $SKILL_DIR — review before committing"
}

cd "$VAULT_ROOT"
git add "skills/$CATEGORY/$SLUG/"

echo "Imported: $SLUG v1 -> skills/$CATEGORY/$SLUG/"
echo "Commit with: git commit -m 'import: $SLUG baseline'"
