# Optimization Policy

This document describes when and how the vault reorganizes itself.

## When to reorganize

Reorganization is warranted when:
- A category has more than 15 skills and a subcategory is clearly justified
- Multiple skills serve the same purpose and could be merged
- A skill is consistently misplaced (users look for it in a different category)
- Two weak categories would be clearer as one
- A new domain emerges that doesn't fit any existing category

Reorganization is NOT warranted when:
- The current structure is working fine
- The change would only move things without improving discoverability
- It would create more categories than are needed

## How to reorganize

1. Identify the improvement clearly
2. Move skills to new locations
3. Update metadata.json `category` field for each moved skill
4. Update registry.json, categories.json, and lineage.json
5. Update category INDEX.md files
6. Update any README cross-references
7. Commit with message: `reorg: <description>`

## Skill optimization

When a skill is improved or rewritten:
1. Save the current version to `versions/vN/` first
2. Update SKILL.md with the new content
3. Increment version in metadata.json and CURRENT.md
4. Append a line to CHANGELOG.md
5. Run a safety review
6. Commit: `optimize: skill-name vN`

## Merge policy

When two skills should be combined:
1. Create the new merged skill in the appropriate category
2. Move both old skills to `_obsolete/`
3. Update their README.md files with supersession notices
4. Record the merge in lineage.json
5. Commit: `merge: skill-a + skill-b -> new-skill`

## Review cadence

Review `state/optimization-state.json` and `state/structure-state.json` periodically. If pending actions accumulate, address them before they compound.
