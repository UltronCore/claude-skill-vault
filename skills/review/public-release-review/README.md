# Public Release Review

**Category:** review
**Status:** active
**Version:** v1
**Public Safe:** yes

## What it does

Runs a pre-publication quality gate on any skill headed to the public repository. Checks for private data, documentation completeness, version consistency, changelog accuracy, and generates concise public update notes when meaningful changes have been made.

## When to use

- Before publishing a skill publicly for the first time
- Before pushing a meaningful update to an already-public skill
- During pre-push review cycles when a public-facing skill has changed
- During weekly vault maintenance when public skills were modified

## What it produces

- Silent pass when all checks clear
- A concise BLOCKED or NEEDS FIXES block when issues are found
- Auto-generated public update notes added to README and CHANGELOG when meaningful changes occurred

## How it integrates

Runs automatically as **Phase 2F** inside vault-push-guardian, triggered when any `public_safe: true` skill appears in the pre-push diff. Can also be invoked directly on a specific skill before manual publication.

## Checks performed

1. **Public safety** — scans for personal info, credentials, private paths, and internal references
2. **README quality** — verifies purpose, use cases, category, version, and status are present and clear
3. **Version visibility** — ensures version matches across README, CURRENT.md, and metadata.json
4. **CHANGELOG quality** — confirms the changelog has meaningful entries and no trivial noise
5. **Public update notes** — compares current skill against last released version and generates update notes if needed
6. **Download readiness** — confirms folder is clean, well-named, and free of draft or junk files

## Related skills

- [vault-push-guardian](../vault-push-guardian/) — pre-push safety and sync skill; calls this skill in Phase 2F
- [skill-reviewer-and-enhancer](../skill-reviewer-and-enhancer/) — general skill quality review; this skill focuses specifically on public release readiness

## Current release notes

**v1** — Initial release. Provides full public release quality gate with safety, documentation, version, changelog, and update notes checks. Integrated into vault-push-guardian as Phase 2F.
