# Lineage Overview

This document explains how skill lineage is tracked in the vault.

## What lineage tracks

When a skill is created, optimized, merged, split, replaced, or archived, the lineage system records the relationship so the evolution of any skill can be traced forward and backward.

## Lineage file

`skills/_registry/lineage.json` is the central lineage record. Each entry represents a transition event.

## Transition types

| Type | Meaning |
|---|---|
| `superseded` | Skill A was replaced by Skill B |
| `merged-into` | Skill A was merged into Skill B |
| `split-from` | Skill B was split from Skill A |
| `optimized` | Skill A was updated to a new version |
| `archived` | Skill was moved to _archive (no longer active) |
| `moved` | Skill was moved to a different category |

## Reading lineage

To trace a skill's history:
1. Check `metadata.json` for `derived_from` and `replaced_by` fields
2. Check `lineage.json` for full transition history
3. Check the skill's `CHANGELOG.md` for version-level notes
4. Check `_obsolete/` or `_archive/` for older preserved versions

## Obsolete skill behavior

When a skill is superseded:
- The old skill folder is moved to `skills/_obsolete/`
- Its README.md gets a top-level note: "Superseded by: skills/{category}/{new-slug}/"
- Its CURRENT.md is updated to status: superseded
- Its metadata.json `replaced_by` field is set
- The new skill's metadata.json `derived_from` field is set
- A lineage.json entry records the transition

## Archive behavior

Skills in `_archive/` were removed from active use for reasons other than supersession (e.g., the underlying tool was deprecated, the use case no longer applies). They are preserved for historical reference only.
